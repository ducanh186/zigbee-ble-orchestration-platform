import '../models/auth_session.dart';

abstract class TokenStorage {
  Future<AuthSession?> readSession();
  Future<void> saveSession(AuthSession session);
  Future<void> clearSession();
}
