import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/repositories/remote_provisioning_repository.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/provisioning_session.dart';

void main() {
  test('createSession posts provisioning request and maps response', () async {
    Map<String, Object?>? capturedBody;
    final repository = RemoteProvisioningRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/provisioning/sessions');
          capturedBody = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode(_sessionJson(status: 'pending')),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final session = await repository.createSession(
      gatewayId: 'gw-ubuntu-01',
      roomId: 'lab',
      payload: ProvisioningQrPayload.parseJson(
        jsonEncode({
          'version': 1,
          'eui64': 'a8d417feff570b00',
          'install_code': '83fed3407a939723a5c639b26916d505c3b5',
          'device_type': 'light',
          'model': 'EFR32MG12_LIGHT_KIT',
        }),
      ),
    );

    expect(capturedBody, {
      'gateway_id': 'gw-ubuntu-01',
      'room_id': 'lab',
      'device': {
        'eui64': 'A8D417FEFF570B00',
        'install_code': '83FED3407A939723A5C639B26916D505C3B5',
        'device_type': 'light',
        'model': 'EFR32MG12_LIGHT_KIT',
      },
    });
    expect(session.sessionId, 'session-01');
    expect(session.status, ProvisioningStatus.pending);
  });

  test('fetchSession reads current provisioning status', () async {
    final repository = RemoteProvisioningRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/provisioning/sessions/session-01');
          return http.Response(
            jsonEncode(_sessionJson(status: 'permit_open')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final session = await repository.fetchSession('session-01');

    expect(session.status, ProvisioningStatus.permitOpen);
    expect(session.isTerminal, isFalse);
  });

  test('cancelSession deletes active provisioning session', () async {
    final repository = RemoteProvisioningRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/provisioning/sessions/session-01');
          return http.Response(
            jsonEncode(_sessionJson(status: 'cancelled')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final session = await repository.cancelSession('session-01');

    expect(session.status, ProvisioningStatus.cancelled);
    expect(session.isTerminal, isTrue);
  });

  test('pollSession emits statuses until the session reaches terminal state', () async {
    final statuses = ['pending', 'permit_open', 'joined'];
    var requestCount = 0;
    final repository = RemoteProvisioningRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/provisioning/sessions/session-01');
          final status = statuses[requestCount++];
          return http.Response(
            jsonEncode(_sessionJson(status: status)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final emitted = await repository
        .pollSession(
          'session-01',
          interval: Duration.zero,
          maxAttempts: 5,
        )
        .toList();

    expect(
      emitted.map((session) => session.status).toList(),
      [
        ProvisioningStatus.pending,
        ProvisioningStatus.permitOpen,
        ProvisioningStatus.joined,
      ],
    );
    expect(requestCount, 3);
  });
}

Map<String, Object?> _sessionJson({required String status}) {
  return {
    'session_id': 'session-01',
    'status': status,
    'gateway_id': 'gw-ubuntu-01',
    'room_id': 'lab',
    'eui64': 'A8D417FEFF570B00',
    'device_type': 'light',
    'model': 'EFR32MG12_LIGHT_KIT',
    'reason': null,
    'expires_at': '10:00 05/27/2026',
    'created_at': '09:59 05/27/2026',
    'updated_at': '10:00 05/27/2026',
  };
}
