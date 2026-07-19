import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/task_provider.dart';
import '../util/fmt.dart';
import '../widgets/task_card.dart';

/// The daily timeline: tasks in order with live countdowns. Long-press and
/// drag a task down to postpone it — the whole timeline re-chains from the
/// PERT expected durations.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => TodayScreenState();
}

class TodayScreenState extends State<TodayScreen> {
  DateTime day = DateTime.now();

  void goTo(DateTime d) => setState(() => day = d);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = provider.tasksForDay(day);
    final isToday = _sameDay(day, DateTime.now());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    setState(() => day = day.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => day = DateTime.now()),
                  child: Text(
                    isToday ? 'Today · ${fmtDay(day)}' : fmtDay(day),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    setState(() => day = day.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Text(
                    'No tasks planned.\nTap + to add one with PERT estimates.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: tasks.length,
                  onReorder: (oldIndex, newIndex) =>
                      provider.reorder(day, oldIndex, newIndex),
                  itemBuilder: (context, i) => TaskCard(
                    key: ValueKey(tasks[i].id),
                    task: tasks[i],
                    day: day,
                  ),
                ),
        ),
        if (tasks.isNotEmpty) _daySummary(context, provider),
      ],
    );
  }

  /// PERT roll-up for the day: total expected work, projected finish and the
  /// 95% confidence window (±2σ, variances summed along the chain).
  Widget _daySummary(BuildContext context, TaskProvider provider) {
    final pending =
        provider.tasksForDay(day).where((t) => !provider.isDoneOn(t, day));
    if (pending.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Text('🎉 All tasks done for this day!',
            textAlign: TextAlign.center),
      );
    }
    var totalTe = 0.0, totalVar = 0.0;
    DateTime? finish;
    for (final t in pending) {
      totalTe += provider.effectiveExpectedMinutes(t);
      totalVar += provider.effectiveVariance(t);
      final e = provider.endOn(t, day);
      if (finish == null || e.isAfter(finish)) finish = e;
    }
    final sigma = math.sqrt(totalVar);
    final early = finish!.subtract(Duration(minutes: (2 * sigma).round()));
    final late = finish.add(Duration(minutes: (2 * sigma).round()));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        'Remaining: ${fmtMinutes(totalTe)} expected · finish ~${fmtTime(finish)}\n'
        '95% window (±2σ): ${fmtTime(early)} – ${fmtTime(late)}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
