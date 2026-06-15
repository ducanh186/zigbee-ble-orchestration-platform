import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/data/models/automation_api_model.dart';
import 'package:zigbee_smart_building/domain/models/automation_rule.dart';

void main() {
  test('typed schedule draft serializes the shared wire contract', () {
    const draft = AutomationRuleDraft.typed(
      name: 'Weekday light',
      enabled: true,
      trigger: ScheduleAutomationTrigger(cron: '0 7 * * 1-5'),
      scheduleCron: '0 7 * * 1-5',
      actions: [
        DeviceCommandAutomationAction(
          deviceId: 'light-1',
          command: AutomationActionCommand.on,
        ),
      ],
    );

    expect(AutomationRuleDraftApiModel(draft: draft).toJson(), {
      'name': 'Weekday light',
      'enabled': true,
      'trigger_type': 'schedule',
      'schedule_cron': '0 7 * * 1-5',
      'trigger': {'type': 'schedule'},
      'actions': [
        {
          'type': 'device_command',
          'device_id': 'light-1',
          'device_type': 'light',
          'command': 'on',
        },
      ],
    });
  });

  test('legacy event draft serializes canonical discriminators', () {
    const draft = AutomationRuleDraft(
      name: 'Motion light',
      enabled: true,
      triggerDeviceId: 'motion-1',
      triggerDeviceType: AutomationDeviceType.motion,
      triggerEvent: AutomationTriggerEvent.occupancyChanged,
      triggerState: {'occupancy': 'occupied'},
      actionCommand: AutomationActionCommand.on,
      targetLightIds: ['light-1'],
    );

    final json = AutomationRuleDraftApiModel(draft: draft).toJson();

    expect(json['trigger_type'], 'event');
    expect(json['schedule_cron'], isNull);
    expect(json['trigger'], {
      'type': 'device_event',
      'device_id': 'motion-1',
      'device_type': 'sensor',
      'event': 'occupancy_changed',
      'state': {'occupancy': 'occupied'},
    });
  });

  test('sensor threshold and scene action expose canonical payloads', () {
    const trigger = SensorThresholdAutomationTrigger(
      deviceId: 'environment-1',
      metric: EnvironmentMetric.temperature,
      operator: ThresholdOperator.gte,
      threshold: 30,
    );
    const action = SceneActivateAutomationAction(
      groupId: 'group-lab',
      sceneId: 'scene-all-on',
    );

    expect(trigger.toJson(), {
      'type': 'sensor_threshold',
      'device_id': 'environment-1',
      'device_type': 'sensor',
      'metric': 'temperature_c',
      'operator': 'gte',
      'threshold': 30.0,
    });
    expect(action.toJson(), {
      'type': 'scene_activate',
      'group_id': 'group-lab',
      'scene_id': 'scene-all-on',
    });
  });

  test('schedule templates force the expected light command', () {
    expect(
      AutomationRuleTemplate.scheduleOn.actionCommand,
      AutomationActionCommand.on,
    );
    expect(
      AutomationRuleTemplate.scheduleOff.actionCommand,
      AutomationActionCommand.off,
    );
    expect(AutomationRuleTemplate.scheduleOn.isSchedule, isTrue);
    expect(AutomationRuleTemplate.scheduleOff.isSchedule, isTrue);
  });
}
