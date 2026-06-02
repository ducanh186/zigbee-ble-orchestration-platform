import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/auth_session.dart';
import '../../domain/repositories/token_storage.dart';

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _sessionKey = 'auth_session';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        await clearSession();
        return null;
      }

      final accessToken = decoded['accessToken'];
      if (accessToken is! String || accessToken.isEmpty) {
        await clearSession();
        return null;
      }

      final expiresAtRaw = decoded['expiresAt'];
      return AuthSession(
        accessToken: accessToken,
        username: decoded['username'] as String?,
        userId: decoded['userId'] as String?,
        displayName: decoded['displayName'] as String?,
        role: decoded['role'] as String?,
        homeId: decoded['homeId'] as String?,
        mustChangePassword: decoded['mustChangePassword'] == true,
        expiresAt: expiresAtRaw is String
            ? DateTime.tryParse(expiresAtRaw)
            : null,
      );
    } on FormatException {
      await clearSession();
      return null;
    }
  }

  @override
  Future<void> saveSession(AuthSession session) async {
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode(<String, Object?>{
        'accessToken': session.accessToken,
        'username': session.username,
        'userId': session.userId,
        'displayName': session.displayName,
        'role': session.role,
        'homeId': session.homeId,
        'mustChangePassword': session.mustChangePassword,
        'expiresAt': session.expiresAt?.toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<void> clearSession() => _storage.delete(key: _sessionKey);
}
