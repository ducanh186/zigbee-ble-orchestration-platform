import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/repositories/remote_automation_repository.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/automation_rule.dart';

void main() {
  test('fetchRules maps automation list response', () async {
    final repository = RemoteAutomationRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/automations');
          return http.Response(
            jsonEncode([
              {
                'id': 'automation-01',
                'name': 'Motion turns on lab lights',
                'enabled': true,
                'trigger': {
                  'device_id': 'pir-01',
                  'device_type': 'motion',
                  'event': 'occupancy_changed',
                  'state': {'occupancy': 'occupied'},
                },
                'actions': [
                  {
                    'device_id': 'light-01',
                    'device_type': 'light',
                    'command': 'on',
                  },
                ],
                'sync_status': 'pending',
                'last_run_status': 'never_run',
                'last_error': null,
                'created_at': '2026-05-15T08:00:00Z',
                'updated_at': '2026-05-15T08:00:00Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final rules = await repository.fetchRules();

    expect(rules, hasLength(1));
    expect(rules.single.id, 'automation-01');
    expect(rules.single.name, 'Motion turns on lab lights');
    expect(rules.single.syncStatus, AutomationSyncStatus.pending);
    expect(rules.single.lastRunStatus, AutomationLastRunStatus.neverRun);
    expect(rules.single.trigger.deviceId, 'pir-01');
    expect(rules.single.actions.single.command, AutomationActionCommand.on);
  });

  test(
    'createRule posts fixed template payload without faking sync success',
    () async {
      Map<String, Object?>? capturedBody;
      final repository = RemoteAutomationRepository(
        apiClient: ApiClient(
          baseUrl: 'http://98.83.4.87:8000',
          httpClient: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/automations');
            capturedBody = Map<String, Object?>.from(
              jsonDecode(request.body) as Map,
            );
            return http.Response(
              jsonEncode({
                'id': 'automation-01',
                'name': 'Motion turns on lab lights',
                'enabled': true,
                'trigger': capturedBody!['trigger'],
                'actions': capturedBody!['actions'],
                'sync_status': 'pending',
                'last_run_status': 'never_run',
                'last_error': null,
                'created_at': '2026-05-15T08:00:00Z',
                'updated_at': '2026-05-15T08:00:00Z',
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final rule = await repository.createRule(
        const AutomationRuleDraft(
          name: 'Motion turns on lab lights',
          enabled: true,
          template: AutomationRuleTemplate.motionOccupiedTurnsOnLights,
          triggerDeviceId: 'pir-01',
          targetLightIds: ['light-01', 'light-02'],
        ),
      );

      expect(capturedBody, {
        'name': 'Motion turns on lab lights',
        'enabled': true,
        'trigger_type': 'event',
        'schedule_cron': null,
        'trigger': {
          'type': 'device_event',
          'device_id': 'pir-01',
          'device_type': 'motion',
          'event': 'occupancy_changed',
          'state': {'occupancy': 'occupied'},
        },
        'actions': [
          {
            'type': 'device_command',
            'device_id': 'light-01',
            'device_type': 'light',
            'command': 'on',
          },
          {
            'type': 'device_command',
            'device_id': 'light-02',
            'device_type': 'light',
            'command': 'on',
          },
        ],
      });
      expect(rule.syncStatus, AutomationSyncStatus.pending);
    },
  );

  test(
    'createRule emits canonical "switch_toggle" event for switch templates',
    () async {
      Map<String, Object?>? capturedBody;
      final repository = RemoteAutomationRepository(
        apiClient: ApiClient(
          baseUrl: 'http://98.83.4.87:8000',
          httpClient: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/automations');
            capturedBody = Map<String, Object?>.from(
              jsonDecode(request.body) as Map,
            );
            return http.Response(
              jsonEncode({
                'id': 'automation-switch-01',
                'name': 'Hallway switch toggles ceiling light',
                'enabled': true,
                'trigger': capturedBody!['trigger'],
                'actions': capturedBody!['actions'],
                'sync_status': 'pending',
                'last_run_status': 'never_run',
                'last_error': null,
                'created_at': '2026-05-21T08:00:00Z',
                'updated_at': '2026-05-21T08:00:00Z',
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      await repository.createRule(
        const AutomationRuleDraft(
          name: 'Hallway switch toggles ceiling light',
          enabled: true,
          template: AutomationRuleTemplate.switchTogglesOneLight,
          triggerDeviceId: 'switch-01',
          targetLightIds: ['light-01'],
        ),
      );

      final trigger = capturedBody!['trigger'] as Map<String, Object?>;
      expect(capturedBody!['trigger_type'], 'event');
      expect(trigger['type'], 'device_event');
      expect(
        trigger['event'],
        'switch_toggle',
        reason:
            'Switch rule wire payload must use canonical "switch_toggle"; '
            'gateway rejects "toggle" with unsupported_trigger.',
      );
      expect(trigger['device_type'], 'switch');
      expect(trigger['device_id'], 'switch-01');
    },
  );

  test('createRule posts manual switch toggle payload', () async {
    Map<String, Object?>? capturedBody;
    final repository = RemoteAutomationRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          capturedBody = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode({
              'id': 'automation-switch',
              'name': 'Switch toggles lab light',
              'enabled': true,
              'trigger': capturedBody!['trigger'],
              'actions': capturedBody!['actions'],
              'sync_status': 'pending',
              'last_run_status': 'never_run',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await repository.createRule(
      const AutomationRuleDraft(
        name: 'Switch toggles lab light',
        enabled: true,
        triggerDeviceId: 'switch-01',
        triggerDeviceType: AutomationDeviceType.switchDevice,
        triggerEvent: AutomationTriggerEvent.switchToggle,
        actionCommand: AutomationActionCommand.toggle,
        targetLightIds: ['light-01'],
      ),
    );

    expect(capturedBody, {
      'name': 'Switch toggles lab light',
      'enabled': true,
      'trigger_type': 'event',
      'schedule_cron': null,
      'trigger': {
        'type': 'device_event',
        'device_id': 'switch-01',
        'device_type': 'switch',
        'event': 'switch_toggle',
      },
      'actions': [
        {
          'type': 'device_command',
          'device_id': 'light-01',
          'device_type': 'light',
          'command': 'toggle',
        },
      ],
    });
  });

  test('createRule posts manual motion occupied payload', () async {
    Map<String, Object?>? capturedBody;
    final repository = RemoteAutomationRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          capturedBody = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode({
              'id': 'automation-motion-on',
              'name': 'Motion turns on lab light',
              'enabled': true,
              'trigger': capturedBody!['trigger'],
              'actions': capturedBody!['actions'],
              'sync_status': 'pending',
              'last_run_status': 'never_run',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await repository.createRule(
      const AutomationRuleDraft(
        name: 'Motion turns on lab light',
        enabled: true,
        triggerDeviceId: 'pir-01',
        triggerDeviceType: AutomationDeviceType.motion,
        triggerEvent: AutomationTriggerEvent.occupancyChanged,
        triggerState: {'occupancy': 'occupied'},
        actionCommand: AutomationActionCommand.on,
        targetLightIds: ['light-01'],
      ),
    );

    expect(capturedBody!['trigger'], {
      'type': 'device_event',
      'device_id': 'pir-01',
      'device_type': 'motion',
      'event': 'occupancy_changed',
      'state': {'occupancy': 'occupied'},
    });
    expect(capturedBody!['actions'], [
      {
        'type': 'device_command',
        'device_id': 'light-01',
        'device_type': 'light',
        'command': 'on',
      },
    ]);
  });

  test('createRule posts per-target light action payload', () async {
    Map<String, Object?>? capturedBody;
    final repository = RemoteAutomationRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          capturedBody = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode({
              'id': 'automation-mixed-actions',
              'name': 'Motion controls lights differently',
              'enabled': true,
              'trigger': capturedBody!['trigger'],
              'actions': capturedBody!['actions'],
              'sync_status': 'pending',
              'last_run_status': 'never_run',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await repository.createRule(
      const AutomationRuleDraft(
        name: 'Motion controls lights differently',
        enabled: true,
        triggerDeviceId: 'pir-01',
        triggerDeviceType: AutomationDeviceType.motion,
        triggerEvent: AutomationTriggerEvent.occupancyChanged,
        triggerState: {'occupancy': 'occupied'},
        targetLightIds: ['light-01', 'light-02'],
        targetActionCommands: {
          'light-01': AutomationActionCommand.on,
          'light-02': AutomationActionCommand.off,
        },
      ),
    );

    expect(capturedBody!['actions'], [
      {
        'type': 'device_command',
        'device_id': 'light-01',
        'device_type': 'light',
        'command': 'on',
      },
      {
        'type': 'device_command',
        'device_id': 'light-02',
        'device_type': 'light',
        'command': 'off',
      },
    ]);
  });

  test('createRule posts manual motion unoccupied payload', () async {
    Map<String, Object?>? capturedBody;
    final repository = RemoteAutomationRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          capturedBody = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode({
              'id': 'automation-motion-off',
              'name': 'Motion turns off lab light',
              'enabled': true,
              'trigger': capturedBody!['trigger'],
              'actions': capturedBody!['actions'],
              'sync_status': 'pending',
              'last_run_status': 'never_run',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await repository.createRule(
      const AutomationRuleDraft(
        name: 'Motion turns off lab light',
        enabled: true,
        triggerDeviceId: 'pir-01',
        triggerDeviceType: AutomationDeviceType.motion,
        triggerEvent: AutomationTriggerEvent.occupancyChanged,
        triggerState: {'occupancy': 'unoccupied'},
        actionCommand: AutomationActionCommand.off,
        targetLightIds: ['light-01'],
      ),
    );

    expect(capturedBody!['trigger'], {
      'type': 'device_event',
      'device_id': 'pir-01',
      'device_type': 'motion',
      'event': 'occupancy_changed',
      'state': {'occupancy': 'unoccupied'},
    });
    expect(capturedBody!['actions'], [
      {
        'type': 'device_command',
        'device_id': 'light-01',
        'device_type': 'light',
        'command': 'off',
      },
    ]);
  });

  test('deleteRule sends DELETE and accepts empty response', () async {
    final repository = RemoteAutomationRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/automations/automation-01');
          return http.Response('', 204);
        }),
      ),
    );

    await repository.deleteRule('automation-01');
  });
}
