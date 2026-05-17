import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/repositories/remote_device_repository.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/domain/models/device_power.dart';

void main() {
  test('derives gateway online status from cloud event logs', () async {
    final repository = RemoteDeviceRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/events/');
          expect(request.url.query, 'limit=50');
          return http.Response(
            jsonEncode([
              {
                'id': 101,
                'device_id': null,
                'event_type': 'gateway_online',
                'payload': {
                  'value': 'online',
                  'source': 'gateway',
                  'gateway_id': 'gw-ubuntu-01',
                },
                'occurred_at': '10:11 05/07/2026',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final status = await repository.fetchCloudStatus();

    expect(status.state, CloudConnectionState.online);
    expect(status.gatewayId, 'gw-ubuntu-01');
    expect(status.eventType, 'gateway_online');
    expect(status.occurredAt, '10:11 05/07/2026');
  });

  test(
    'does not invent gateway status when cloud logs contain no gateway event',
    () async {
      final repository = RemoteDeviceRepository(
        apiClient: ApiClient(
          baseUrl: 'http://98.83.4.87:8000',
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode([
                {
                  'id': 23,
                  'device_id': '0000000000000053',
                  'event_type': 'occupancy_changed',
                  'payload': {'occupancy': 'unoccupied'},
                  'occurred_at': '09:20 05/06/2026',
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final status = await repository.fetchCloudStatus();

      expect(status.state, CloudConnectionState.unknown);
      expect(status.detail, 'No gateway status log found in cloud events');
    },
  );

  test('derives gateway offline status from cloud event logs', () async {
    final repository = RemoteDeviceRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode([
              {
                'id': 102,
                'device_id': null,
                'event_type': 'gateway_online',
                'payload': {
                  'value': 'offline',
                  'source': 'gateway',
                  'gateway_id': 'gw-ubuntu-01',
                },
                'occurred_at': '10:12 05/07/2026',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final status = await repository.fetchCloudStatus();

    expect(status.state, CloudConnectionState.offline);
    expect(status.gatewayId, 'gw-ubuntu-01');
    expect(status.occurredAt, '10:12 05/07/2026');
  });

  test(
    'refreshDeviceStates fetches latest state for each device via the cloud per-device state endpoint',
    () async {
      final requestedPaths = <String>[];
      final repository = RemoteDeviceRepository(
        apiClient: ApiClient(
          baseUrl: 'http://98.83.4.87:8000',
          httpClient: MockClient((request) async {
            requestedPaths.add(request.url.path);
            final id = request.url.pathSegments.last == 'state'
                ? request.url.pathSegments[
                      request.url.pathSegments.length - 2]
                : request.url.pathSegments.last;
            return http.Response(
              jsonEncode({
                'device_id': id,
                'state': {
                  'power': id == 'light-01' ? 'on' : 'off',
                  'reachable': true,
                },
                'reported_at': '07:30 05/17/2026',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final states = await repository.refreshDeviceStates(const [
        'light-01',
        'light-02',
      ]);

      expect(requestedPaths, [
        '/api/devices/light-01/state',
        '/api/devices/light-02/state',
      ]);
      expect(states, hasLength(2));
      expect(states[0].deviceId, 'light-01');
      expect(states[0].power, DevicePower.on);
      expect(states[0].reportedAt, '07:30 05/17/2026');
      expect(states[1].deviceId, 'light-02');
      expect(states[1].power, DevicePower.off);
    },
  );

  test(
    'refreshDeviceStates returns unreachable power when state reports reachable=false',
    () async {
      final repository = RemoteDeviceRepository(
        apiClient: ApiClient(
          baseUrl: 'http://98.83.4.87:8000',
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'device_id': 'light-03',
                'state': {'power': 'off', 'reachable': false},
                'reported_at': '06:52 05/07/2026',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final states = await repository.refreshDeviceStates(const ['light-03']);

      expect(states, hasLength(1));
      expect(states.single.power, DevicePower.unreachable);
    },
  );

  test(
    'refreshDeviceStates skips devices whose state endpoint returns 404',
    () async {
      final repository = RemoteDeviceRepository(
        apiClient: ApiClient(
          baseUrl: 'http://98.83.4.87:8000',
          httpClient: MockClient((request) async {
            final id = request.url.pathSegments[
                request.url.pathSegments.length - 2];
            if (id == 'light-missing') {
              return http.Response(
                jsonEncode({'detail': 'No state reported for this device'}),
                404,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode({
                'device_id': id,
                'state': {'power': 'on', 'reachable': true},
                'reported_at': '07:30 05/17/2026',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final states = await repository.refreshDeviceStates(const [
        'light-01',
        'light-missing',
      ]);

      expect(states, hasLength(1));
      expect(states.single.deviceId, 'light-01');
    },
  );

  test(
    'refreshDeviceStates surfaces non-404 ApiException without swallowing it',
    () async {
      final repository = RemoteDeviceRepository(
        apiClient: ApiClient(
          baseUrl: 'http://98.83.4.87:8000',
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({'detail': 'boom'}),
              500,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      await expectLater(
        repository.refreshDeviceStates(const ['light-01']),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    },
  );
}
