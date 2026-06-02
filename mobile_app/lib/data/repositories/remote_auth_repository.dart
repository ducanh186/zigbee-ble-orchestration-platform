import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/token_storage.dart';
import '../services/api_client.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required ApiClient apiClient,
    TokenStorage? tokenStorage,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage? _tokenStorage;

  @override
  Future<AuthSession?> restoreSession() async {
    final storage = _tokenStorage;
    if (storage == null) {
      _apiClient.setAccessToken(null);
      return null;
    }

    final session = await storage.readSession();
    if (session == null) {
      _apiClient.setAccessToken(null);
      return null;
    }

    if (session.isExpired) {
      await storage.clearSession();
      _apiClient.setAccessToken(null);
      return null;
    }

    _apiClient.setAccessToken(session.accessToken);
    try {
      final json = await _apiClient.getJson('/auth/me');
      final refreshed = _sessionFromMap(
        Map<String, Object?>.from(json as Map),
        accessToken: session.accessToken,
        fallbackExpiresAt: session.expiresAt,
      );
      await storage.saveSession(refreshed);
      return refreshed;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await storage.clearSession();
        _apiClient.setAccessToken(null);
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final json = await _apiClient.postJson('/auth/login', <String, Object?>{
      'username': username,
      'password': password,
    });
    final session = _sessionFromMap(Map<String, Object?>.from(json as Map));

    // SCRUM-29: wire the bearer token into the shared ApiClient so
    // subsequent authenticated calls (devices, automation, logs) carry it.
    // Owning this side effect in the repository keeps the view model free
    // of API-client knowledge.
    _apiClient.setAccessToken(session.accessToken);
    await _tokenStorage?.saveSession(session);

    return session;
  }

  AuthSession _sessionFromMap(
    Map<String, Object?> map, {
    String? accessToken,
    DateTime? fallbackExpiresAt,
  }) {
    final rawAccessToken = accessToken ?? map['access_token'];
    if (rawAccessToken is! String || rawAccessToken.isEmpty) {
      throw const ApiException(
        statusCode: 200,
        kind: ApiErrorKind.unknown,
        message: 'Auth response missing access_token',
      );
    }
    final sessionUsername = map['username'] as String?;
    final userId = map['user_id'] as String?;
    final displayName = map['display_name'] as String?;
    final role = map['role'] as String?;
    final homeId = map['home_id'] as String?;
    final mustChangePassword = map['must_change_password'] == true;
    final expiresAtRaw = map['expires_at'] as String?;
    return AuthSession(
      accessToken: rawAccessToken,
      username: sessionUsername,
      userId: userId,
      displayName: displayName,
      role: role,
      homeId: homeId,
      mustChangePassword: mustChangePassword,
      expiresAt: expiresAtRaw == null
          ? fallbackExpiresAt
          : DateTime.tryParse(expiresAtRaw),
    );
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final stored = await _tokenStorage?.readSession();
    if (stored != null && !stored.isExpired) {
      _apiClient.setAccessToken(stored.accessToken);
    }
    try {
      await _apiClient.postJson('/auth/change-password', <String, Object?>{
        'old_password': oldPassword,
        'new_password': newPassword,
      });
    } finally {
      _apiClient.setAccessToken(null);
      await _tokenStorage?.clearSession();
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.postJson('/auth/logout', <String, Object?>{});
    } finally {
      // Always clear the token locally even if the server call fails so the
      // client cannot accidentally reuse a revoked bearer.
      _apiClient.setAccessToken(null);
      await _tokenStorage?.clearSession();
    }
  }
}
