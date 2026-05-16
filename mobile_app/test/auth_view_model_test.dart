import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/ui/features/auth/view_models/auth_view_model.dart';

class FakeAuthRepository implements AuthRepository {
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
}

class FailingAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    throw Exception('401 unauthorized');
  }

  @override
  Future<void> logout() async {}
}

void main() {
  test('login stores an authenticated session', () async {
    final viewModel = AuthViewModel(repository: FakeAuthRepository());

    await viewModel.login(username: 'operator', password: 'password');

    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.session?.accessToken, 'test-token');
    expect(viewModel.errorMessage, isNull);
  });

  test('login surfaces error message when repository throws', () async {
    final viewModel = AuthViewModel(repository: FailingAuthRepository());

    await viewModel.login(username: 'operator', password: 'wrong');

    expect(viewModel.isAuthenticated, isFalse);
    expect(viewModel.session, isNull);
    expect(viewModel.errorMessage, isNotNull);
    expect(viewModel.errorMessage, contains('401 unauthorized'));
  });
}
