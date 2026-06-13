import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/ui/features/auth/view_models/auth_view_model.dart';

class FakeAuthRepository implements AuthRepository {
  AuthSession? restoredSession;
  int changePasswordCalls = 0;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    return AuthSession(
      accessToken: 'test-token',
      username: 'parent',
      userId: 'parent-1',
      role: 'parent',
      expiresAt: DateTime.utc(2026, 5, 16, 12),
    );
  }

  @override
  Future<AuthSession?> refreshSession({required String refreshToken}) async =>
      null;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession?> restoreSession() async => restoredSession;

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    changePasswordCalls++;
  }
}

class FailingAuthRepository implements AuthRepository {
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
  Future<AuthSession?> refreshSession({required String refreshToken}) async =>
      null;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}
}

class RestoreFailingAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    throw StateError('login is not part of this test');
  }

  @override
  Future<AuthSession?> refreshSession({required String refreshToken}) async =>
      null;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession?> restoreSession() async {
    throw const ApiException(
      statusCode: 0,
      kind: ApiErrorKind.unknown,
      message: 'secure storage read failed',
    );
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    throw StateError('changePassword is not part of this test');
  }
}

void main() {
  test('login stores an authenticated session', () async {
    final viewModel = AuthViewModel(repository: FakeAuthRepository());

    await viewModel.login(username: 'parent', password: 'password');

    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.session?.accessToken, 'test-token');
    expect(viewModel.errorMessage, isNull);
  });

  test('bootstrap restores an existing authenticated session', () async {
    final repository = FakeAuthRepository()
      ..restoredSession = AuthSession(
        accessToken: 'stored-token',
        username: 'parent',
        userId: 'parent-1',
        role: 'parent',
        expiresAt: DateTime.utc(2026, 5, 16, 12),
      );
    final viewModel = AuthViewModel(repository: repository);

    await viewModel.bootstrap();

    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.session?.accessToken, 'stored-token');
    expect(viewModel.errorMessage, isNull);
  });

  test(
    'bootstrap falls back to login without surfacing restore errors',
    () async {
      final viewModel = AuthViewModel(
        repository: RestoreFailingAuthRepository(),
      );

      await viewModel.bootstrap();

      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.session, isNull);
      expect(viewModel.errorMessage, isNull);
    },
  );

  test('login surfaces error message when repository throws', () async {
    final viewModel = AuthViewModel(repository: FailingAuthRepository());

    await viewModel.login(username: 'parent', password: 'wrong');

    expect(viewModel.isAuthenticated, isFalse);
    expect(viewModel.session, isNull);
    expect(viewModel.errorMessage, isNotNull);
    // Surface a friendly message; never leak raw HTTP / exception text.
    expect(viewModel.errorMessage, contains('Login failed'));
    expect(viewModel.errorMessage, isNot(contains('invalid credentials')));
    expect(viewModel.errorMessage, isNot(contains('API 401')));
  });

  test(
    'changePassword clears authenticated session after repository success',
    () async {
      final repository = FakeAuthRepository();
      final viewModel = AuthViewModel(repository: repository);
      await viewModel.login(username: 'parent', password: 'password');

      await viewModel.changePassword(
        oldPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      expect(repository.changePasswordCalls, 1);
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.session, isNull);
      expect(viewModel.errorMessage, isNull);
    },
  );
}
