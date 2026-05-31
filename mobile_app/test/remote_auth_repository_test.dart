import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/repositories/remote_auth_repository.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/repositories/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
  AuthSession? session;
  int clearCalls = 0;

  @override
  Future<void> clearSession() async {
    clearCalls++;
    session = null;
  }

  @override
  Future<AuthSession?> readSession() async => session;

  @override
  Future<void> saveSession(AuthSession session) async {
    this.session = session;
  }
}

void main() {
  test(
    'login parses access_token, user_id, role, home_id, expires_at',
    () async {
      final tokenStorage = FakeTokenStorage();
      final repository = RemoteAuthRepository(
        tokenStorage: tokenStorage,
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
                'role': 'user',
                'home_id': 'home-1',
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
      expect(session.role, 'user');
      expect(session.homeId, 'home-1');
      expect(session.expiresAt, DateTime.utc(2026, 5, 16, 12));
      expect(tokenStorage.session?.accessToken, 'token-abc');
    },
  );

  test(
    'restoreSession returns stored unexpired token and primes ApiClient',
    () async {
      final tokenStorage = FakeTokenStorage()
        ..session = AuthSession(
          accessToken: 'stored-token',
          userId: 'operator-1',
          role: 'user',
          homeId: 'home-1',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );
      late Map<String, String> headers;
      final apiClient = ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          headers = request.headers;
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repository = RemoteAuthRepository(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      );

      final session = await repository.restoreSession();
      await apiClient.getJson('/devices');

      expect(session?.accessToken, 'stored-token');
      expect(headers['Authorization'], 'Bearer stored-token');
    },
  );

  test('restoreSession clears expired stored token', () async {
    final tokenStorage = FakeTokenStorage()
      ..session = AuthSession(
        accessToken: 'expired-token',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
    final repository = RemoteAuthRepository(
      apiClient: ApiClient(baseUrl: 'http://98.83.4.87:8000'),
      tokenStorage: tokenStorage,
    );

    final session = await repository.restoreSession();

    expect(session, isNull);
    expect(tokenStorage.clearCalls, 1);
  });

  test('login throws ApiException when access_token is missing', () async {
    final repository = RemoteAuthRepository(
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'user_id': 'operator-1'}),
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
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
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
