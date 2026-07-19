import 'dart:math' as math;

/// How a task repeats on the calendar.
enum Recurrence { none, daily, weekly, monthly }

/// A task (or subtask) whose duration is estimated with PERT three-point
/// estimation:
///
///   TE (expected time)   = (O + 4M + P) / 6
///   sigma (std deviation) = (P - O) / 6
///   variance             = sigma^2
///
/// where O = optimistic, M = most likely, P = pessimistic (all in minutes).
/// The end time of a task is always start + TE, so the schedule is derived
/// from the estimates rather than entered by hand.
class PertTask {
  PertTask({
    required this.id,
    this.parentId,
    required this.title,
    this.notes = '',
    required this.optimisticMin,
    required this.likelyMin,
    required this.pessimisticMin,
    required this.scheduledStart,
    this.sortOrder = 0,
    this.completed = false,
    this.completedAt,
    this.recurrence = Recurrence.none,
    List<int>? weekdays,
  }) : weekdays = weekdays ?? [];

  final String id;
  String? parentId;
  String title;
  String notes;
  double optimisticMin;
  double likelyMin;
  double pessimisticMin;
  DateTime scheduledStart;
  int sortOrder;
  bool completed;
  DateTime? completedAt;
  Recurrence recurrence;

  /// For [Recurrence.weekly]: DateTime.monday (1) .. DateTime.sunday (7).
  List<int> weekdays;

  double get expectedMinutes =>
      (optimisticMin + 4 * likelyMin + pessimisticMin) / 6.0;

  double get stdDevMinutes => (pessimisticMin - optimisticMin) / 6.0;

  double get varianceMinutes => math.pow(stdDevMinutes, 2).toDouble();

  bool get isRecurring => recurrence != Recurrence.none;

  /// The start of this task's occurrence on [day] (same time of day as
  /// [scheduledStart]).
  DateTime startOn(DateTime day) => DateTime(
      day.year, day.month, day.day, scheduledStart.hour, scheduledStart.minute);

  /// Whether an occurrence of this task falls on calendar day [day].
  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final first = DateTime(
        scheduledStart.year, scheduledStart.month, scheduledStart.day);
    switch (recurrence) {
      case Recurrence.none:
        return d == first;
      case Recurrence.daily:
        return !d.isBefore(first);
      case Recurrence.weekly:
        return !d.isBefore(first) && weekdays.contains(d.weekday);
      case Recurrence.monthly:
        return !d.isBefore(first) && d.day == scheduledStart.day;
    }
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'parentId': parentId,
        'title': title,
        'notes': notes,
        'optimisticMin': optimisticMin,
        'likelyMin': likelyMin,
        'pessimisticMin': pessimisticMin,
        'scheduledStart': scheduledStart.millisecondsSinceEpoch,
        'sortOrder': sortOrder,
        'completed': completed ? 1 : 0,
        'completedAt': completedAt?.millisecondsSinceEpoch,
        'recurrence': recurrence.index,
        'weekdays': weekdays.join(','),
      };

  factory PertTask.fromMap(Map<String, Object?> m) => PertTask(
        id: m['id'] as String,
        parentId: m['parentId'] as String?,
        title: m['title'] as String,
        notes: (m['notes'] as String?) ?? '',
        optimisticMin: (m['optimisticMin'] as num).toDouble(),
        likelyMin: (m['likelyMin'] as num).toDouble(),
        pessimisticMin: (m['pessimisticMin'] as num).toDouble(),
        scheduledStart:
            DateTime.fromMillisecondsSinceEpoch(m['scheduledStart'] as int),
        sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
        completed: (m['completed'] as num?) == 1,
        completedAt: m['completedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['completedAt'] as int),
        recurrence: Recurrence.values[(m['recurrence'] as num?)?.toInt() ?? 0],
        weekdays: ((m['weekdays'] as String?) ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList(),
      );
}
