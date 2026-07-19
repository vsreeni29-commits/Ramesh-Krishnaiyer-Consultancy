import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Alarm-style reminders scheduled through Android's AlarmManager
/// (via flutter_local_notifications). The OS wakes the device exactly at the
/// scheduled time — the app itself keeps no background service running, so
/// battery impact is negligible.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to the package default if the platform lookup fails.
    }

    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  NotificationDetails get _alarmDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          'pert_task_alarms',
          'Task alarms',
          channelDescription: 'Start and end alarms for planned tasks',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
        ),
      );

  /// Schedules an exact alarm at [when]. If [repeat] is given the alarm
  /// repeats on that component match (e.g. same time daily); [when] must then
  /// be the next future occurrence.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    DateTimeComponents? repeat,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (repeat == null && scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _alarmDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeat,
      );
    } catch (_) {
      // Exact-alarm permission may have been declined; skip silently rather
      // than crash — the in-app countdowns still work.
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
