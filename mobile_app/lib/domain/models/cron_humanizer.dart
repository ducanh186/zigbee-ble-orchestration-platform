/// Turns a 5-field cron string into a short, human-readable English phrase for
/// display on saved rules (e.g. `35 * * * *` -> "every hour at minute 35").
///
/// Handles the shapes the app's schedule builder emits (hourly / daily /
/// weekdays / weekly) and falls back to the raw cron for anything else.
String humanizeCron(String cron) {
  final trimmed = cron.trim();
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length != 5) {
    return 'on schedule "$trimmed"';
  }
  final minute = parts[0];
  final hour = parts[1];
  final dom = parts[2];
  final month = parts[3];
  final dow = parts[4];

  // Hourly: "m * * * *"
  if (hour == '*' &&
      dom == '*' &&
      month == '*' &&
      dow == '*' &&
      _isInt(minute)) {
    return 'every hour at minute $minute';
  }

  // Time-based shapes need a concrete minute + hour, any month, any day-of-month.
  if (_isInt(minute) && _isInt(hour) && dom == '*' && month == '*') {
    final time = '${_two(hour)}:${_two(minute)}';
    if (dow == '*') {
      return 'every day at $time';
    }
    if (dow == '1-5') {
      return 'every weekday at $time';
    }
    final weekday = _weekday(dow);
    if (weekday != null) {
      return 'every $weekday at $time';
    }
  }

  return 'on schedule "$trimmed"';
}

bool _isInt(String value) => int.tryParse(value) != null;

String _two(String value) => value.padLeft(2, '0');

String? _weekday(String dow) {
  const names = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  final index = int.tryParse(dow);
  if (index == null || index < 0 || index > 6) {
    return null;
  }
  return names[index];
}
