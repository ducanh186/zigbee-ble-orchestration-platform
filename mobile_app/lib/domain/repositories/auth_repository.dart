import '../models/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> login({
    required String username,
    required String password,
  });

  Future<AuthSession?> refreshSession({required String refreshToken});

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  Future<void> logout();
}
