import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';

void main() {
  test('refreshes once on 401 and retries the original request', () async {
    var currentSession = AuthSession(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    var refreshCalls = 0;
    final authHeaders = <String?>[];
    final client = ApiClient(
      baseUrl: 'http://example.test',
      currentSessionProvider: () async => currentSession,
      refreshSession: (refreshToken) async {
        refreshCalls++;
        expect(refreshToken, 'old-refresh');
        currentSession = AuthSession(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        );
        return currentSession;
      },
      httpClient: MockClient((request) async {
        authHeaders.add(request.headers['Authorization']);
        if (authHeaders.length == 1) {
          return http.Response(
            jsonEncode({'detail': 'expired token'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    )..setAccessToken('old-access');

    final response = await client.getJson('/api/devices');

    expect(response, {'ok': true});
    expect(refreshCalls, 1);
    expect(authHeaders, ['Bearer old-access', 'Bearer new-access']);
  });

  test(
    'does not refresh more than once when retried request is still 401',
    () async {
      var currentSession = AuthSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
      );
      var refreshCalls = 0;
      var requestCalls = 0;
      final client = ApiClient(
        baseUrl: 'http://example.test',
        currentSessionProvider: () async => currentSession,
        refreshSession: (refreshToken) async {
          refreshCalls++;
          currentSession = AuthSession(
            accessToken: 'new-access',
            refreshToken: 'new-refresh',
            refreshExpiresAt: DateTime.now().toUtc().add(
              const Duration(days: 1),
            ),
          );
          return currentSession;
        },
        httpClient: MockClient((request) async {
          requestCalls++;
          return http.Response(
            jsonEncode({'detail': 'still unauthorized'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }),
      )..setAccessToken('old-access');

      await expectLater(
        () => client.getJson('/api/devices'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );

      expect(refreshCalls, 1);
      expect(requestCalls, 2);
    },
  );
}
