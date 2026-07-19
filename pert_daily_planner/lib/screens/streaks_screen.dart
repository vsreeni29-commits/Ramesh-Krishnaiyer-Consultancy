import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/task_provider.dart';

/// Streaks for recurring habits: current run, best run and the last 7 days.
class StreaksScreen extends StatelessWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final habits = provider.recurringTasks;
    final today = DateTime.now();

    if (habits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No repeating tasks yet.\nGive a task a Daily/Weekly/Monthly '
            'repeat and your streaks will show up here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: habits.length,
      itemBuilder: (context, i) {
        final t = habits[i];
        final doneToday = provider.isDoneOn(t, today);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(t.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔥 Current streak: ${provider.currentStreak(t)} days'
                      '   ·   🏆 Best: ${provider.bestStreak(t)} days'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var d = 6; d >= 0; d--)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: CircleAvatar(
                            radius: 7,
                            backgroundColor: provider.isDoneOn(
                                    t, today.subtract(Duration(days: d)))
                                ? Colors.green
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text('last 7 days',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            trailing: FilledButton.tonal(
              onPressed: () => provider.toggleDone(t, today),
              child: Text(doneToday ? 'Done ✓' : 'Do it'),
            ),
          ),
        );
      },
    );
  }
}
