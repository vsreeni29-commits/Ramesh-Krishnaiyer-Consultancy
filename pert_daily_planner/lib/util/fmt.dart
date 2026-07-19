import 'package:intl/intl.dart';

final _timeFmt = DateFormat('HH:mm');
final _dayFmt = DateFormat('EEE, d MMM yyyy');

String fmtTime(DateTime d) => _timeFmt.format(d);

String fmtDay(DateTime d) => _dayFmt.format(d);

/// "1h 05m" / "35m" from fractional minutes.
String fmtMinutes(double minutes) {
  final m = minutes.round();
  if (m < 60) return '${m}m';
  return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
}

/// "02:15:09" (or "1d 02:15:09") countdown clock from a duration.
String fmtClock(Duration d) {
  final total = d.inSeconds.abs();
  final days = total ~/ 86400;
  final h = (total % 86400) ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final hms = '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
  return days > 0 ? '${days}d $hms' : hms;
}
