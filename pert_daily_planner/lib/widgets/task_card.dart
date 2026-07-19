import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../screens/task_edit_screen.dart';
import '../util/fmt.dart';

/// A task row: completion toggle, auto-calculated start–end window, PERT
/// estimate chips, a live countdown label, streak badge and nested subtasks.
class TaskCard extends StatefulWidget {
  const TaskCard({super.key, required this.task, required this.day});

  final PertTask task;
  final DateTime day;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final t = widget.task;
    final day = widget.day;
    final done = provider.isDoneOn(t, day);
    final start = t.startOn(day);
    final end = provider.endOn(t, day);
    final kids = provider.children(t.id);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              leading: IconButton(
                icon: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? Colors.green : theme.colorScheme.outline,
                ),
                tooltip: done ? 'Mark as not done' : 'Mark completed',
                onPressed: () => provider.toggleDone(t, day),
              ),
              title: Text(
                t.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text('${fmtTime(start)} – ${fmtTime(end)}'
                  '${t.isRecurring ? '  ·  ${_recurrenceLabel(t)}' : ''}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t.isRecurring && provider.currentStreak(t) > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Text('🔥'),
                        label: Text('${provider.currentStreak(t)}'),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) => _onMenu(context, v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                          value: 'subtask', child: Text('Add subtask')),
                      if (!t.isRecurring)
                        const PopupMenuItem(
                            value: 'postpone',
                            child: Text('Postpone to tomorrow')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              onTap: () => _openEditor(context, t),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pertChip(context,
                      'O ${fmtMinutes(t.optimisticMin)} · M ${fmtMinutes(t.likelyMin)} · P ${fmtMinutes(t.pessimisticMin)}'),
                  _pertChip(context,
                      'TE ${fmtMinutes(provider.effectiveExpectedMinutes(t))} ± ${fmtMinutes(provider.effectiveStdDev(t))}',
                      emphasized: true),
                  _countdownChip(context, done, start, end),
                ],
              ),
            ),
            for (final k in kids)
              Padding(
                padding: const EdgeInsets.only(left: 40, right: 12),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        provider.isDoneOn(k, day)
                            ? Icons.check_circle_outline
                            : Icons.circle_outlined,
                        size: 18,
                        color: provider.isDoneOn(k, day)
                            ? Colors.green
                            : theme.colorScheme.outline,
                      ),
                      onPressed: () => provider.toggleDone(k, day),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _openEditor(context, k),
                        child: Text(
                          k.title,
                          style: TextStyle(
                            decoration: provider.isDoneOn(k, day)
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
                    Text('TE ${fmtMinutes(k.expectedMinutes)}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pertChip(BuildContext context, String label,
      {bool emphasized = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasized ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Widget _countdownChip(
      BuildContext context, bool done, DateTime start, DateTime end) {
    final now = DateTime.now();
    String label;
    Color color;
    if (done) {
      label = '✓ Done';
      color = Colors.green;
    } else if (now.isBefore(start)) {
      label = '⏳ Starts in ${fmtClock(start.difference(now))}';
      color = Colors.blueGrey;
    } else if (now.isBefore(end)) {
      label = '▶ ${fmtClock(end.difference(now))} left';
      color = Colors.orange.shade800;
    } else {
      label = '⚠ Over by ${fmtClock(now.difference(end))}';
      color = Colors.red.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _recurrenceLabel(PertTask t) {
    switch (t.recurrence) {
      case Recurrence.daily:
        return 'Daily';
      case Recurrence.weekly:
        return 'Weekly';
      case Recurrence.monthly:
        return 'Monthly';
      case Recurrence.none:
        return '';
    }
  }

  void _onMenu(BuildContext context, String action) {
    final provider = context.read<TaskProvider>();
    switch (action) {
      case 'edit':
        _openEditor(context, widget.task);
      case 'subtask':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaskEditScreen(
                day: widget.day, parentId: widget.task.id)));
      case 'postpone':
        provider.postponeToNextDay(widget.task);
      case 'delete':
        provider.deleteTask(widget.task);
    }
  }

  void _openEditor(BuildContext context, PertTask t) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TaskEditScreen(day: widget.day, existing: t)));
  }
}
