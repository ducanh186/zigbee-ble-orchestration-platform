import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/repositories/remote_device_repository.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';

void main() {
  test(
    'fetchDevices uses the canonical list endpoint without redirect',
    () async {
      final requests = <Uri>[];
      final apiClient = ApiClient(
        baseUrl: 'https://dashboard.iot-building.app',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          expect(request.headers['Authorization'], 'Bearer token-abc');
          if (request.url.path == '/api/devices/') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'light-01',
                  'device_type': 'light',
                  'eui64': '00124b0001aa22bb',
                  'room_id': 'room-01',
                  'name': 'Desk lamp',
                  'is_online': true,
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/devices/light-01/state') {
            return http.Response(
              jsonEncode({
                'device_id': 'light-01',
                'state': {'power': 'on', 'level': 100, 'reachable': true},
                'reported_at': '10:11 06/02/2026',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected path ${request.url.path}', 404);
        }),
      );
      apiClient.setAccessToken('token-abc');
      final repository = RemoteDeviceRepository(apiClient: apiClient);

      final devices = await repository.fetchDevices();

      expect(devices, hasLength(1));
      expect(requests.first.path, '/api/devices/');
    },
  );

  test('maps a v2 sensor (kind 2) from inline list state', () async {
    final requests = <Uri>[];
    final repository = RemoteDeviceRepository(
      apiClient: ApiClient(
        baseUrl: 'https://dashboard.iot-building.app',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path == '/api/devices/') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'environment-01',
                  'device_type': 'sensor',
                  'sensor_kind': 2,
                  'eui64': '00124b0001dht011',
                  'room_id': 'room-01',
                  'name': 'DHT11 Sensor',
                  'is_online': true,
                  // latest state is now inlined by the list endpoint
                  'state': {
                    'temperature_c': 28.5,
                    'humidity_percent': 48,
                    'sensor': 'dht11',
                    'reachable': true,
                  },
                  'reported_at': '10:11 06/13/2026',
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected path ${request.url.path}', 404);
        }),
      ),
    );

    final device = (await repository.fetchDevices()).single;

    expect(device.isEnvironment, isTrue);
    expect(device.sensorKind, 2);
    expect(device.temperatureC, 28.5);
    expect(device.humidityPercent, 48);
    expect(device.sensorLabel, 'dht11');
    expect(device.reportedAt, '10:11 06/13/2026');
    // No per-device /state fan-out — only the list endpoint is hit.
    expect(requests.map((u) => u.path), ['/api/devices/']);
  });

  test(
    'renameDeviceName patches display label and preserves gateway identity',
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
    },
  );

  test('createRoom posts the parent room name and returns the room', () async {
    final apiClient = ApiClient(
      baseUrl: 'http://98.83.4.87:8000',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/rooms/');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body, {'name': 'Meeting Room'});
        return http.Response(
          jsonEncode({'id': 'room-new', 'name': 'Meeting Room'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = RemoteDeviceRepository(apiClient: apiClient);

    final room = await repository.createRoom('Meeting Room');

    expect(room.id, 'room-new');
    expect(room.name, 'Meeting Room');
  });

  test('renameRoom patches the room name and returns the room', () async {
    final apiClient = ApiClient(
      baseUrl: 'http://98.83.4.87:8000',
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/rooms/room-1');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body, {'name': 'Studio'});
        return http.Response(
          jsonEncode({'id': 'room-1', 'name': 'Studio'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = RemoteDeviceRepository(apiClient: apiClient);

    final room = await repository.renameRoom(roomId: 'room-1', name: 'Studio');

    expect(room.id, 'room-1');
    expect(room.name, 'Studio');
  });

  test('deleteRoom deletes a room and returns the deleted room', () async {
    final apiClient = ApiClient(
      baseUrl: 'http://98.83.4.87:8000',
      httpClient: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/rooms/room-1');
        return http.Response(
          jsonEncode({'id': 'room-1', 'name': 'Studio'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = RemoteDeviceRepository(apiClient: apiClient);

    final room = await repository.deleteRoom('room-1');

    expect(room.id, 'room-1');
    expect(room.name, 'Studio');
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

  test('reads gateway online status from the dedicated endpoint', () async {
    final repository = RemoteDeviceRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/gateways/gw-ubuntu-01/status');
          expect(request.url.query, isEmpty);
          return http.Response(
            jsonEncode({
              'gateway_id': 'gw-ubuntu-01',
              'status': 'online',
              'event_type': 'gateway_online',
              'occurred_at': '10:11 05/07/2026',
            }),
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
    'does not invent home hub status when the endpoint reports unknown',
    () async {
      final repository = RemoteDeviceRepository(
        apiClient: ApiClient(
          baseUrl: 'http://98.83.4.87:8000',
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'gateway_id': 'gw-ubuntu-01',
                'status': 'unknown',
                'event_type': null,
                'occurred_at': null,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final status = await repository.fetchCloudStatus();

      expect(status.state, CloudConnectionState.unknown);
      expect(status.detail, 'No home hub status log found in cloud');
    },
  );

  test('reads gateway offline status from the dedicated endpoint', () async {
    final repository = RemoteDeviceRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'gateway_id': 'gw-ubuntu-01',
              'status': 'offline',
              'event_type': 'gateway_online',
              'occurred_at': '10:12 05/07/2026',
            }),
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
