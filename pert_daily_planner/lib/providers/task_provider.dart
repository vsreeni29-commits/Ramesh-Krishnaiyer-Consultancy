import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../services/db.dart';
import '../services/notification_service.dart';

/// Central state: task CRUD, PERT roll-ups over subtasks, the day timeline
/// re-flow (drag to postpone), streaks for recurring tasks, and alarm
/// scheduling for every start/end time.
class TaskProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  final List<PertTask> _tasks = [];

  /// taskId -> set of day keys (yyyy-MM-dd) on which a recurring task was done.
  final Map<String, Set<String>> _completions = {};

  List<PertTask> get allTasks => List.unmodifiable(_tasks);

  List<PertTask> get recurringTasks =>
      _tasks.where((t) => t.parentId == null && t.isRecurring).toList();

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> load() async {
    _tasks
      ..clear()
      ..addAll(await TaskDb.instance.fetchTasks());
    _completions
      ..clear()
      ..addAll(await TaskDb.instance.fetchCompletions());
    await _rescheduleAll();
    notifyListeners();
  }

  PertTask? byId(String? id) {
    if (id == null) return null;
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<PertTask> children(String parentId) =>
      _tasks.where((t) => t.parentId == parentId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  // ---------------------------------------------------------------- PERT ---

  /// Expected duration in minutes. If a task is broken into subtasks its
  /// duration is the PERT chain sum of the subtasks' expected times.
  double effectiveExpectedMinutes(PertTask t) {
    final kids = children(t.id);
    if (kids.isEmpty) return t.expectedMinutes;
    return kids.fold(0.0, (sum, k) => sum + effectiveExpectedMinutes(k));
  }

  /// Variance in minutes^2; variances add along a PERT chain.
  double effectiveVariance(PertTask t) {
    final kids = children(t.id);
    if (kids.isEmpty) return t.varianceMinutes;
    return kids.fold(0.0, (sum, k) => sum + effectiveVariance(k));
  }

  double effectiveStdDev(PertTask t) => math.sqrt(effectiveVariance(t));

  DateTime endOn(PertTask t, DateTime day) => t
      .startOn(day)
      .add(Duration(minutes: effectiveExpectedMinutes(t).round()));

  // ------------------------------------------------------------- queries ---

  /// Top-level tasks occurring on [day], in timeline order.
  List<PertTask> tasksForDay(DateTime day) =>
      _tasks.where((t) => t.parentId == null && t.occursOn(day)).toList()
        ..sort((a, b) => a.sortOrder != b.sortOrder
            ? a.sortOrder.compareTo(b.sortOrder)
            : a.scheduledStart.compareTo(b.scheduledStart));

  bool isDoneOn(PertTask t, DateTime day) => t.isRecurring
      ? (_completions[t.id]?.contains(dayKey(day)) ?? false)
      : t.completed;

  // ---------------------------------------------------------------- CRUD ---

  String newId() => _uuid.v4();

  Future<void> addTask(PertTask t) async {
    t.sortOrder = tasksForDay(_dateOnly(t.scheduledStart)).length;
    _tasks.add(t);
    await TaskDb.instance.upsertTask(t);
    await _rescheduleAll();
    notifyListeners();
  }

  Future<void> updateTask(PertTask t) async {
    await TaskDb.instance.upsertTask(t);
    await _rescheduleAll();
    notifyListeners();
  }

  Future<void> deleteTask(PertTask t) async {
    _tasks.removeWhere((x) => x.id == t.id || x.parentId == t.id);
    _completions.remove(t.id);
    await TaskDb.instance.deleteTask(t.id);
    await _rescheduleAll();
    notifyListeners();
  }

  // ------------------------------------------------------- done / streaks ---

  Future<void> toggleDone(PertTask t, DateTime day) async {
    if (t.isRecurring) {
      final key = dayKey(day);
      final set = _completions.putIfAbsent(t.id, () => <String>{});
      if (set.contains(key)) {
        set.remove(key);
        await TaskDb.instance.removeCompletion(t.id, key);
      } else {
        set.add(key);
        await TaskDb.instance.addCompletion(t.id, key);
      }
    } else {
      t.completed = !t.completed;
      t.completedAt = t.completed ? DateTime.now() : null;
      await TaskDb.instance.upsertTask(t);
    }
    await _rescheduleAll();
    notifyListeners();
  }

  /// Consecutive completed days ending today (or yesterday, if today is still
  /// pending).
  int currentStreak(PertTask t) {
    final set = _completions[t.id] ?? const <String>{};
    var day = _dateOnly(DateTime.now());
    if (!set.contains(dayKey(day))) day = day.subtract(const Duration(days: 1));
    var streak = 0;
    while (set.contains(dayKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int bestStreak(PertTask t) {
    final dates = (_completions[t.id] ?? const <String>{})
        .map(DateTime.parse)
        .toList()
      ..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in dates) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  // ------------------------------------------- timeline re-flow / postpone ---

  /// Handles a drag re-order in the day list: dragging a task down postpones
  /// it behind the tasks it was dropped after, then the whole day's timeline
  /// is re-chained from the PERT durations.
  Future<void> reorder(DateTime day, int oldIndex, int newIndex) async {
    final list = tasksForDay(day);
    if (newIndex > oldIndex) newIndex--;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    for (var i = 0; i < list.length; i++) {
      list[i].sortOrder = i;
      await TaskDb.instance.upsertTask(list[i]);
    }
    await reflowDay(day);
  }

  /// Re-chains the day's pending tasks: the first keeps its start time, every
  /// following task starts when the previous one's PERT expected time ends.
  Future<void> reflowDay(DateTime day) async {
    final pending =
        tasksForDay(day).where((t) => !isDoneOn(t, day)).toList();
    if (pending.isNotEmpty) {
      var cursor = pending.first.startOn(day);
      for (final t in pending) {
        // Keep the record's own date (recurring tasks share one record);
        // only the time of day moves.
        t.scheduledStart = DateTime(
            t.scheduledStart.year,
            t.scheduledStart.month,
            t.scheduledStart.day,
            cursor.hour,
            cursor.minute);
        await TaskDb.instance.upsertTask(t);
        cursor =
            cursor.add(Duration(minutes: effectiveExpectedMinutes(t).round()));
      }
    }
    await _rescheduleAll();
    notifyListeners();
  }

  /// Pushes a one-off task to the next day.
  Future<void> postponeToNextDay(PertTask t) async {
    if (t.isRecurring) return;
    t.scheduledStart = t.scheduledStart.add(const Duration(days: 1));
    await TaskDb.instance.upsertTask(t);
    await _rescheduleAll();
    notifyListeners();
  }

  // ------------------------------------------------------------- alarms ---

  Future<void> _rescheduleAll() async {
    final n = NotificationService.instance;
    await n.cancelAll();
    for (final t in _tasks.where((t) => t.parentId == null)) {
      final mins = effectiveExpectedMinutes(t).round();
      final base = (t.id.hashCode & 0x07ffffff) * 16;
      final startTitle = '▶ Start: ${t.title}';
      final endTitle = '⏱ Time up: ${t.title}';
      final startBody = 'PERT expected duration: $mins min — countdown begins';
      final endBody = 'The PERT expected time ($mins min) has elapsed';

      switch (t.recurrence) {
        case Recurrence.none:
          if (t.completed) break;
          final start = t.scheduledStart;
          await n.schedule(
              id: base, title: startTitle, body: startBody, when: start);
          await n.schedule(
              id: base + 1,
              title: endTitle,
              body: endBody,
              when: start.add(Duration(minutes: mins)));
        case Recurrence.daily:
          final start = _nextDaily(t.scheduledStart);
          await n.schedule(
              id: base,
              title: startTitle,
              body: startBody,
              when: start,
              repeat: DateTimeComponents.time);
          await n.schedule(
              id: base + 1,
              title: endTitle,
              body: endBody,
              when: start.add(Duration(minutes: mins)),
              repeat: DateTimeComponents.time);
        case Recurrence.weekly:
          for (var i = 0; i < t.weekdays.length && i < 7; i++) {
            final start = _nextWeekly(t.weekdays[i], t.scheduledStart);
            await n.schedule(
                id: base + 2 + i * 2,
                title: startTitle,
                body: startBody,
                when: start,
                repeat: DateTimeComponents.dayOfWeekAndTime);
            await n.schedule(
                id: base + 3 + i * 2,
                title: endTitle,
                body: endBody,
                when: start.add(Duration(minutes: mins)),
                repeat: DateTimeComponents.dayOfWeekAndTime);
          }
        case Recurrence.monthly:
          final start = _nextMonthly(t.scheduledStart);
          await n.schedule(
              id: base,
              title: startTitle,
              body: startBody,
              when: start,
              repeat: DateTimeComponents.dayOfMonthAndTime);
          await n.schedule(
              id: base + 1,
              title: endTitle,
              body: endBody,
              when: start.add(Duration(minutes: mins)),
              repeat: DateTimeComponents.dayOfMonthAndTime);
      }
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _nextDaily(DateTime anchor) {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day, anchor.hour, anchor.minute);
    if (!d.isAfter(now)) d = d.add(const Duration(days: 1));
    return d;
  }

  static DateTime _nextWeekly(int weekday, DateTime anchor) {
    var d = _nextDaily(anchor);
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  static DateTime _nextMonthly(DateTime anchor) {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, anchor.day, anchor.hour, anchor.minute);
    while (!d.isAfter(now)) {
      d = DateTime(d.year, d.month + 1, anchor.day, anchor.hour, anchor.minute);
    }
    return d;
  }
}
