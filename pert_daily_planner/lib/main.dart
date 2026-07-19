import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/task_provider.dart';
import 'screens/calendar_screen.dart';
import 'screens/streaks_screen.dart';
import 'screens/task_edit_screen.dart';
import 'screens/today_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  final provider = TaskProvider();
  await provider.load();
  runApp(ChangeNotifierProvider.value(
    value: provider,
    child: const PertPlannerApp(),
  ));
}

class PertPlannerApp extends StatelessWidget {
  const PertPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PERT Daily Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  static const _titles = ['Daily plan', 'Calendar', 'Streaks'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          TodayScreen(),
          CalendarScreen(),
          StreaksScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add task',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaskEditScreen(day: DateTime.now()))),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.view_agenda_outlined),
              selectedIcon: Icon(Icons.view_agenda),
              label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar'),
          NavigationDestination(
              icon: Icon(Icons.local_fire_department_outlined),
              selectedIcon: Icon(Icons.local_fire_department),
              label: 'Streaks'),
        ],
      ),
    );
  }
}
