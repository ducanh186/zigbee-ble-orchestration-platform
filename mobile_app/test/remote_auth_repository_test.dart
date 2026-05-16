import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/repositories/remote_auth_repository.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';

void main() {
  test('login parses access_token, user_id, expires_at from response',
      () async {
    final repository = RemoteAuthRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/auth/login');
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['username'], 'operator');
          expect(body['password'], 'password');
          return http.Response(
            jsonEncode({
              'access_token': 'token-abc',
              'user_id': 'operator-1',
              'expires_at': '2026-05-16T12:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final session = await repository.login(
      username: 'operator',
      password: 'password',
    );

    expect(session.accessToken, 'token-abc');
    expect(session.userId, 'operator-1');
    expect(session.expiresAt, DateTime.utc(2026, 5, 16, 12));
  });

  test('login throws ApiException when access_token is missing', () async {
    final repository = RemoteAuthRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'user_id': 'operator-1',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    expect(
      () => repository.login(username: 'operator', password: 'password'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('access_token'),
        ),
      ),
    );
  });

  test('login propagates ApiException on HTTP 401', () async {
    final repository = RemoteAuthRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'invalid credentials'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    expect(
      () => repository.login(username: 'operator', password: 'bad'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });

  test('logout POSTs to /auth/logout', () async {
    var calledMethod = '';
    var calledPath = '';
    final repository = RemoteAuthRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          calledMethod = request.method;
          calledPath = request.url.path;
          return http.Response(
            '',
            204,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await repository.logout();

    expect(calledMethod, 'POST');
    expect(calledPath, '/auth/logout');
  });
}
