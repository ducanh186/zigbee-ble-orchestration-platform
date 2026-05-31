import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/repositories/remote_device_repository.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';

void main() {
  test('renameDeviceName patches display label and preserves gateway identity',
      () async {
    final apiClient = ApiClient(
      baseUrl: 'http://98.83.4.87:8000',
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/devices/light-01');
        expect(request.headers['authorization'], 'Bearer token-abc');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body, {'name': 'Desk lamp'});
        return http.Response(
          jsonEncode({
            'id': 'light-01',
            'device_type': 'light',
            'eui64': '00124b0001aa22bb',
            'room_id': 'room-1',
            'name': 'Desk lamp',
            'is_online': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    apiClient.setAccessToken('token-abc');
    final repository = RemoteDeviceRepository(apiClient: apiClient);

    final renamed = await repository.renameDeviceName(
      deviceId: 'light-01',
      name: 'Desk lamp',
    );

    expect(renamed.id, 'light-01');
    expect(renamed.eui64, '00124b0001aa22bb');
    expect(renamed.name, 'Desk lamp');
  });

  test('fetchEvents for device reads three recent cloud event rows', () async {
    final repository = RemoteDeviceRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/events/');
          expect(request.url.query, 'device_id=pir-01&limit=3');
          return http.Response(
            jsonEncode([
              {
                'id': 201,
                'device_id': 'pir-01',
                'event_type': 'occupancy_changed',
                'payload': {'occupancy': 'occupied'},
                'occurred_at': '07:20 05/21/2026',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final events = await repository.fetchEvents(deviceId: 'pir-01');

    expect(events, hasLength(1));
    expect(events.single.deviceId, 'pir-01');
    expect(events.single.eventType, 'occupancy_changed');
  });

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
}
