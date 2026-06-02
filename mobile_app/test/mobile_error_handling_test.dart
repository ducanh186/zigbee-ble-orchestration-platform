import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/ui/features/auth/view_models/auth_view_model.dart';

void main() {
  group('ApiClient classifies repository-level failures', () {
    test('maps HTTP 401 to ApiErrorKind.unauthorized', () async {
      final client = ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((_) async {
          return http.Response(
            '{"detail":"invalid token"}',
            401,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        () => client.getJson('/api/devices'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('maps HTTP 422 to ApiErrorKind.validation', () async {
      final client = ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((_) async {
          return http.Response(
            '{"detail":"name required"}',
            422,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        () => client.postJson('/api/automations', const {}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.validation,
          ),
        ),
      );
    });

    test('maps HTTP 500 to ApiErrorKind.server', () async {
      final client = ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((_) async {
          return http.Response('upstream blew up', 500);
        }),
      );

      await expectLater(
        () => client.getJson('/api/devices'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
    });

    test('maps SocketException to ApiErrorKind.offline', () async {
      final client = ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((_) async {
          throw const SocketException('Host unreachable');
        }),
      );

      await expectLater(
        () => client.getJson('/api/devices'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.offline,
          ),
        ),
      );
    });

    test('maps TimeoutException to ApiErrorKind.timeout', () async {
      final client = ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((_) async {
          throw TimeoutException('deadline exceeded');
        }),
      );

      await expectLater(
        () => client.getJson('/api/devices'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.timeout,
          ),
        ),
      );
    });
  });

  group('friendlyErrorMessage', () {
    test('produces user-friendly text without raw exception details', () {
      const raw = ApiException(
        statusCode: 401,
        kind: ApiErrorKind.unauthorized,
        message: 'API 401: {"detail":"bad token"}',
      );
      final message = friendlyErrorMessage(raw, context: 'Dang nhap that bai');

      expect(message, contains('Dang nhap that bai'));
      expect(message, contains('Phien dang nhap'));
      // Raw exception payload must NOT leak into the user-facing message.
      expect(message, isNot(contains('bad token')));
      expect(message, isNot(contains('{"detail"')));
      expect(message, isNot(contains('API 401')));
    });

    test('maps offline error to a network-oriented friendly string', () {
      const raw = ApiException(
        statusCode: 0,
        kind: ApiErrorKind.offline,
        message: 'Failed host lookup',
      );
      final message = friendlyErrorMessage(raw);

      expect(message, contains('Khong co ket noi mang'));
      expect(message, isNot(contains('Failed host lookup')));
    });

    test('falls back to a generic message for non-ApiException errors', () {
      final message = friendlyErrorMessage(Exception('boom'));

      expect(message, contains('khong xac dinh'));
      expect(message, isNot(contains('boom')));
    });
  });

  group('view-model surfaces friendly messages, not raw exceptions', () {
    test(
      'AuthViewModel maps an unauthorized ApiException to friendly text',
      () async {
        final viewModel = AuthViewModel(
          repository: _UnauthorizedAuthRepository(),
        );

        await viewModel.login(username: 'parent', password: 'wrong');

        expect(viewModel.isAuthenticated, isFalse);
        expect(viewModel.errorMessage, isNotNull);
        expect(viewModel.errorMessage, contains('Dang nhap that bai'));
        expect(viewModel.errorMessage, contains('Phien dang nhap'));
        // The raw ApiException toString() format must not be surfaced.
        expect(viewModel.errorMessage, isNot(contains('API 401')));
        expect(viewModel.errorMessage, isNot(contains('invalid credentials')));
      },
    );
  });
}

class _UnauthorizedAuthRepository implements AuthRepository {
  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    throw const ApiException(
      statusCode: 401,
      kind: ApiErrorKind.unauthorized,
      message: 'invalid credentials',
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}
}
