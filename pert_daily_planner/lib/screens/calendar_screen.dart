import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';

/// Month / two-week / week calendar with task markers; tapping a day lists
/// that day's tasks (recurring occurrences included) below the calendar.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final dayTasks = provider.tasksForDay(_selectedDay);

    return Column(
      children: [
        TableCalendar<PertTask>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _format,
          availableCalendarFormats: const {
            CalendarFormat.month: 'Month',
            CalendarFormat.twoWeeks: '2 weeks',
            CalendarFormat.week: 'Week',
          },
          startingDayOfWeek: StartingDayOfWeek.monday,
          eventLoader: provider.tasksForDay,
          selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
          onDaySelected: (selected, focused) => setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          }),
          onFormatChanged: (f) => setState(() => _format = f),
          onPageChanged: (f) => _focusedDay = f,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: dayTasks.isEmpty
              ? Center(
                  child: Text('No tasks on this day',
                      style: Theme.of(context).textTheme.bodyLarge))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 96),
                  itemCount: dayTasks.length,
                  itemBuilder: (context, i) => TaskCard(
                    key: ValueKey('cal-${dayTasks[i].id}'),
                    task: dayTasks[i],
                    day: _selectedDay,
                  ),
                ),
        ),
      ],
    );
  }
}
