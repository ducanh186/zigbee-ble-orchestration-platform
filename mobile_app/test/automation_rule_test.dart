import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/domain/models/automation_rule.dart';

void main() {
  group('AutomationTriggerEvent wire format', () {
    test('switchToggle serializes to canonical "switch_toggle"', () {
      expect(
        AutomationTriggerEvent.switchToggle.wireValue,
        'switch_toggle',
        reason:
            'Contract docs/AUTOMATION_MQTT_CONTRACT.md §4.3 mandates '
            '"switch_toggle"; gateway automation_rule.c only accepts this.',
      );
    });

    test('occupancyChanged serializes to canonical "occupancy_changed"', () {
      expect(
        AutomationTriggerEvent.occupancyChanged.wireValue,
        'occupancy_changed',
      );
    });

    test('fromJson accepts canonical "switch_toggle"', () {
      expect(
        AutomationTriggerEvent.fromJson('switch_toggle'),
        AutomationTriggerEvent.switchToggle,
      );
    });

    test('fromJson accepts legacy "toggle" for backward compatibility', () {
      expect(
        AutomationTriggerEvent.fromJson('toggle'),
        AutomationTriggerEvent.switchToggle,
        reason:
            'Older API responses or cached rules may still contain '
            '"toggle"; parsing them must not throw.',
      );
    });

    test('fromJson accepts "occupancy_changed"', () {
      expect(
        AutomationTriggerEvent.fromJson('occupancy_changed'),
        AutomationTriggerEvent.occupancyChanged,
      );
    });
  });
}
