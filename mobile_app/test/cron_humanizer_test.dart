import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/domain/models/cron_humanizer.dart';

void main() {
  test('hourly at a minute', () {
    expect(humanizeCron('35 * * * *'), 'every hour at minute 35');
  });

  test('daily at a time', () {
    expect(humanizeCron('0 7 * * *'), 'every day at 07:00');
  });

  test('weekdays at a time', () {
    expect(humanizeCron('30 6 * * 1-5'), 'every weekday at 06:30');
  });

  test('weekly on a single day', () {
    expect(humanizeCron('0 7 * * 3'), 'every Wednesday at 07:00');
    expect(humanizeCron('0 22 * * 0'), 'every Sunday at 22:00');
  });

  test('unrecognized shape falls back to the raw cron', () {
    expect(humanizeCron('*/15 * * * *'), 'on schedule "*/15 * * * *"');
  });

  test('malformed cron falls back', () {
    expect(humanizeCron('bad'), 'on schedule "bad"');
  });
}
