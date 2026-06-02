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
    'login parses access_token, username, user_id, role, home_id, must_change_password, expires_at',
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
            expect(body['username'], 'parent');
            expect(body['password'], 'password');
            return http.Response(
              jsonEncode({
                'access_token': 'token-abc',
                'username': 'parent',
                'user_id': 'parent-1',
                'display_name': 'Demo Parent',
                'role': 'parent',
                'home_id': 'home-1',
                'must_change_password': true,
                'expires_at': '2026-05-16T12:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final session = await repository.login(
        username: 'parent',
        password: 'password',
      );

      expect(session.accessToken, 'token-abc');
      expect(session.username, 'parent');
      expect(session.userId, 'parent-1');
      expect(session.displayName, 'Demo Parent');
      expect(session.role, 'parent');
      expect(session.homeId, 'home-1');
      expect(session.mustChangePassword, isTrue);
      expect(session.expiresAt, DateTime.utc(2026, 5, 16, 12));
      expect(tokenStorage.session?.username, 'parent');
      expect(tokenStorage.session?.accessToken, 'token-abc');
    },
  );

  test(
    'restoreSession validates stored token with auth me and refreshes saved user info',
    () async {
      final tokenStorage = FakeTokenStorage()
        ..session = AuthSession(
          accessToken: 'stored-token',
          username: 'parent',
          userId: 'parent-1',
          role: 'parent',
          homeId: 'home-1',
          mustChangePassword: false,
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );
      final paths = <String>[];
      final authHeaders = <String?>[];
      final apiClient = ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          authHeaders.add(request.headers['Authorization']);
          if (request.url.path == '/auth/me') {
            return http.Response(
              jsonEncode({
                'username': 'parent',
                'user_id': 'parent-1',
                'display_name': 'Demo Parent',
                'role': 'parent',
                'home_id': 'home-1',
                'must_change_password': true,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
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
      expect(session?.displayName, 'Demo Parent');
      expect(session?.mustChangePassword, isTrue);
      expect(paths, ['/auth/me', '/devices']);
      expect(authHeaders, ['Bearer stored-token', 'Bearer stored-token']);
      expect(tokenStorage.session?.displayName, 'Demo Parent');
    },
  );

  test('restoreSession clears stored token when auth me rejects it', () async {
    final tokenStorage = FakeTokenStorage()
      ..session = AuthSession(
        accessToken: 'stored-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
    final repository = RemoteAuthRepository(
      tokenStorage: tokenStorage,
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/me');
          return http.Response(
            jsonEncode({'detail': 'Unknown bearer token user'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final session = await repository.restoreSession();

    expect(session, isNull);
    expect(tokenStorage.clearCalls, 1);
  });

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
            jsonEncode({'user_id': 'parent-1'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    expect(
      () => repository.login(username: 'parent', password: 'password'),
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
      () => repository.login(username: 'parent', password: 'bad'),
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

  test('changePassword POSTs and clears local session', () async {
    final tokenStorage = FakeTokenStorage()
      ..session = const AuthSession(accessToken: 'stored-token');
    var calledPath = '';
    var requestBody = <String, Object?>{};
    final repository = RemoteAuthRepository(
      tokenStorage: tokenStorage,
      apiClient: ApiClient(
        baseUrl: 'http://98.83.4.87:8000',
        httpClient: MockClient((request) async {
          calledPath = request.url.path;
          requestBody = jsonDecode(request.body) as Map<String, Object?>;
          expect(request.headers['Authorization'], 'Bearer stored-token');
          return http.Response('', 204);
        }),
      ),
    );

    await repository.changePassword(
      oldPassword: 'old-pass',
      newPassword: 'new-pass',
    );

    expect(calledPath, '/auth/change-password');
    expect(requestBody, {
      'old_password': 'old-pass',
      'new_password': 'new-pass',
    });
    expect(tokenStorage.clearCalls, 1);
  });
}
