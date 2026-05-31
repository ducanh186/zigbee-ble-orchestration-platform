import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/ui/features/auth/view_models/auth_view_model.dart';

class FakeAuthRepository implements AuthRepository {
  AuthSession? restoredSession;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    return AuthSession(
      accessToken: 'test-token',
      userId: 'operator-1',
      expiresAt: DateTime.utc(2026, 5, 16, 12),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession?> restoreSession() async => restoredSession;
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
  Future<void> logout() async {}

  @override
  Future<AuthSession?> restoreSession() async => null;
}

void main() {
  test('login stores an authenticated session', () async {
    final viewModel = AuthViewModel(repository: FakeAuthRepository());

    await viewModel.login(username: 'operator', password: 'password');

    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.session?.accessToken, 'test-token');
    expect(viewModel.errorMessage, isNull);
  });

  test('bootstrap restores an existing authenticated session', () async {
    final repository = FakeAuthRepository()
      ..restoredSession = AuthSession(
        accessToken: 'stored-token',
        userId: 'operator-1',
        expiresAt: DateTime.utc(2026, 5, 16, 12),
      );
    final viewModel = AuthViewModel(repository: repository);

    await viewModel.bootstrap();

    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.session?.accessToken, 'stored-token');
    expect(viewModel.errorMessage, isNull);
  });

  test('login surfaces error message when repository throws', () async {
    final viewModel = AuthViewModel(repository: FailingAuthRepository());

    await viewModel.login(username: 'operator', password: 'wrong');

    expect(viewModel.isAuthenticated, isFalse);
    expect(viewModel.session, isNull);
    expect(viewModel.errorMessage, isNotNull);
    // Surface a friendly message; never leak raw HTTP / exception text.
    expect(viewModel.errorMessage, contains('Dang nhap that bai'));
    expect(viewModel.errorMessage, isNot(contains('invalid credentials')));
    expect(viewModel.errorMessage, isNot(contains('API 401')));
  });
}
