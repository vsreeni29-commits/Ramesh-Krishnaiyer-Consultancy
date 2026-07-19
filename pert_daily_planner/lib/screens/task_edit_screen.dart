import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../util/fmt.dart';

/// Create / edit a task. The user enters the three PERT estimates
/// (optimistic, most likely, pessimistic); the app computes the expected
/// duration TE = (O + 4M + P) / 6 and σ = (P − O) / 6 live, and derives the
/// end time automatically from the chosen start.
class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({super.key, required this.day, this.existing, this.parentId});

  final DateTime day;
  final PertTask? existing;
  final String? parentId;

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _optimistic;
  late final TextEditingController _likely;
  late final TextEditingController _pessimistic;
  late DateTime _date;
  late TimeOfDay _time;
  late Recurrence _recurrence;
  late Set<int> _weekdays;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _optimistic =
        TextEditingController(text: e != null ? _num(e.optimisticMin) : '');
    _likely = TextEditingController(text: e != null ? _num(e.likelyMin) : '');
    _pessimistic =
        TextEditingController(text: e != null ? _num(e.pessimisticMin) : '');
    final start = e?.scheduledStart ??
        DateTime(widget.day.year, widget.day.month, widget.day.day,
            TimeOfDay.now().hour, TimeOfDay.now().minute);
    _date = DateTime(start.year, start.month, start.day);
    _time = TimeOfDay(hour: start.hour, minute: start.minute);
    _recurrence = e?.recurrence ?? Recurrence.none;
    _weekdays = {...?e?.weekdays};
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_title, _notes, _optimistic, _likely, _pessimistic]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _o => double.tryParse(_optimistic.text);
  double? get _m => double.tryParse(_likely.text);
  double? get _p => double.tryParse(_pessimistic.text);

  double? get _te {
    final o = _o, m = _m, p = _p;
    if (o == null || m == null || p == null) return null;
    return (o + 4 * m + p) / 6.0;
  }

  double? get _sigma {
    final o = _o, p = _p;
    if (o == null || p == null) return null;
    return (p - o) / 6.0;
  }

  DateTime get _start =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final isSubtask =
        widget.parentId != null || widget.existing?.parentId != null;
    final te = _te;
    final sigma = _sigma;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing
            ? 'Edit ${isSubtask ? 'subtask' : 'task'}'
            : 'New ${isSubtask ? 'subtask' : 'task'}'),
        actions: [
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () async {
                await context.read<TaskProvider>().deleteTask(widget.existing!);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Notes (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Text('PERT time estimates (minutes)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _estField(_optimistic, 'Optimistic (O)')),
                const SizedBox(width: 8),
                Expanded(child: _estField(_likely, 'Most likely (M)')),
                const SizedBox(width: 8),
                Expanded(child: _estField(_pessimistic, 'Pessimistic (P)')),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PERT calculation',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(te == null || sigma == null
                        ? 'Enter O, M and P to see the expected time.\n'
                            'TE = (O + 4M + P) ÷ 6,  σ = (P − O) ÷ 6'
                        : 'TE = (O + 4M + P) ÷ 6 = ${fmtMinutes(te)}\n'
                            'σ = (P − O) ÷ 6 = ${fmtMinutes(sigma.abs())}\n'
                            'Start ${fmtTime(_start)} → auto end '
                            '${fmtTime(_start.add(Duration(minutes: te.round())))}'
                            '  (95%: ±${fmtMinutes(2 * sigma.abs())})'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(fmtDay(_date)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_time.format(context)),
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: _time);
                      if (t != null) setState(() => _time = t);
                    },
                  ),
                ),
              ],
            ),
            if (!isSubtask) ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<Recurrence>(
                value: _recurrence,
                decoration: const InputDecoration(
                    labelText: 'Repeat', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: Recurrence.none, child: Text('Does not repeat')),
                  DropdownMenuItem(
                      value: Recurrence.daily, child: Text('Daily (streak)')),
                  DropdownMenuItem(
                      value: Recurrence.weekly,
                      child: Text('Weekly (pick days)')),
                  DropdownMenuItem(
                      value: Recurrence.monthly,
                      child: Text('Monthly (same date)')),
                ],
                onChanged: (v) =>
                    setState(() => _recurrence = v ?? Recurrence.none),
              ),
              if (_recurrence == Recurrence.weekly) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var wd = DateTime.monday; wd <= DateTime.sunday; wd++)
                      FilterChip(
                        label: Text(
                            const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][wd - 1]),
                        selected: _weekdays.contains(wd),
                        onSelected: (sel) => setState(() =>
                            sel ? _weekdays.add(wd) : _weekdays.remove(wd)),
                      ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: Text(editing ? 'Save changes' : 'Add to plan'),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _estField(TextEditingController c, String label) => TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: (_) => setState(() {}),
        validator: (v) {
          final n = double.tryParse(v ?? '');
          if (n == null || n <= 0) return '> 0';
          return null;
        },
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final o = _o!, m = _m!, p = _p!;
    if (!(o <= m && m <= p)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Estimates must satisfy O ≤ M ≤ P')));
      return;
    }
    if (_recurrence == Recurrence.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick at least one weekday for a weekly repeat')));
      return;
    }
    final provider = context.read<TaskProvider>();
    final e = widget.existing;
    if (e == null) {
      await provider.addTask(PertTask(
        id: provider.newId(),
        parentId: widget.parentId,
        title: _title.text.trim(),
        notes: _notes.text.trim(),
        optimisticMin: o,
        likelyMin: m,
        pessimisticMin: p,
        scheduledStart: _start,
        recurrence: widget.parentId == null ? _recurrence : Recurrence.none,
        weekdays: _weekdays.toList()..sort(),
      ));
    } else {
      e
        ..title = _title.text.trim()
        ..notes = _notes.text.trim()
        ..optimisticMin = o
        ..likelyMin = m
        ..pessimisticMin = p
        ..scheduledStart = _start
        ..recurrence = e.parentId == null ? _recurrence : Recurrence.none
        ..weekdays = (_weekdays.toList()..sort());
      await provider.updateTask(e);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
