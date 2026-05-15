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
        'trigger': {
          'device_id': 'pir-01',
          'device_type': 'motion',
          'event': 'occupancy_changed',
          'state': {'occupancy': 'occupied'},
        },
        'actions': [
          {'device_id': 'light-01', 'device_type': 'light', 'command': 'on'},
          {'device_id': 'light-02', 'device_type': 'light', 'command': 'on'},
        ],
      });
      expect(rule.syncStatus, AutomationSyncStatus.pending);
    },
  );
}
