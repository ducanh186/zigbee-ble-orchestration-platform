import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/token_storage.dart';
import '../services/api_client.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required ApiClient apiClient,
    TokenStorage? tokenStorage,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage {
    _apiClient.configureAuthHooks(
      currentSessionProvider: () async {
        final storage = _tokenStorage;
        return storage == null ? null : await storage.readSession();
      },
      refreshSession: (refreshToken) =>
          refreshSession(refreshToken: refreshToken),
    );
  }

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
      final refreshToken = session.refreshToken;
      if (refreshToken == null ||
          refreshToken.isEmpty ||
          session.isRefreshExpired) {
        await storage.clearSession();
        _apiClient.setAccessToken(null);
        return null;
      }
      return refreshSession(refreshToken: refreshToken);
    }

    _apiClient.setAccessToken(session.accessToken);
    try {
      final json = await _apiClient.getJson('/auth/me');
      final current = await storage.readSession() ?? session;
      final refreshed = _sessionFromMap(
        Map<String, Object?>.from(json as Map),
        accessToken: current.accessToken,
        refreshToken: current.refreshToken,
        fallbackExpiresAt: current.expiresAt,
        fallbackRefreshExpiresAt: current.refreshExpiresAt,
      );
      await storage.saveSession(refreshed);
      _apiClient.setAccessToken(refreshed.accessToken);
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
    }, authenticate: false);
    final session = _sessionFromMap(Map<String, Object?>.from(json as Map));
    _apiClient.setAccessToken(session.accessToken);
    await _tokenStorage?.saveSession(session);
    return session;
  }

  @override
  Future<AuthSession?> refreshSession({required String refreshToken}) async {
    try {
      final json = await _apiClient.postJson('/auth/refresh', <String, Object?>{
        'refresh_token': refreshToken,
      }, authenticate: false);
      final session = _sessionFromMap(Map<String, Object?>.from(json as Map));
      _apiClient.setAccessToken(session.accessToken);
      await _tokenStorage?.saveSession(session);
      return session;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _tokenStorage?.clearSession();
        _apiClient.setAccessToken(null);
        return null;
      }
      rethrow;
    }
  }

  AuthSession _sessionFromMap(
    Map<String, Object?> map, {
    String? accessToken,
    String? refreshToken,
    DateTime? fallbackExpiresAt,
    DateTime? fallbackRefreshExpiresAt,
  }) {
    final rawAccessToken = accessToken ?? map['access_token'];
    if (rawAccessToken is! String || rawAccessToken.isEmpty) {
      throw const ApiException(
        statusCode: 200,
        kind: ApiErrorKind.unknown,
        message: 'Auth response missing access_token',
      );
    }
    final rawRefreshToken = refreshToken ?? map['refresh_token'];
    final sessionUsername = map['username'] as String?;
    final userId = map['user_id'] as String?;
    final displayName = map['display_name'] as String?;
    final role = map['role'] as String?;
    final homeId = map['home_id'] as String?;
    final mustChangePassword = map['must_change_password'] == true;
    final expiresAtRaw = map['expires_at'] as String?;
    final refreshExpiresAtRaw = map['refresh_expires_at'] as String?;
    return AuthSession(
      accessToken: rawAccessToken,
      refreshToken: rawRefreshToken is String && rawRefreshToken.isNotEmpty
          ? rawRefreshToken
          : null,
      username: sessionUsername,
      userId: userId,
      displayName: displayName,
      role: role,
      homeId: homeId,
      mustChangePassword: mustChangePassword,
      expiresAt: expiresAtRaw == null
          ? fallbackExpiresAt
          : DateTime.tryParse(expiresAtRaw),
      refreshExpiresAt: refreshExpiresAtRaw == null
          ? fallbackRefreshExpiresAt
          : DateTime.tryParse(refreshExpiresAtRaw),
    );
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final stored = await _tokenStorage?.readSession();
    if (stored != null && stored.accessToken.isNotEmpty) {
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
    final stored = await _tokenStorage?.readSession();
    try {
      await _apiClient.postJson('/auth/logout', <String, Object?>{
        'refresh_token': stored?.refreshToken,
      }, authenticate: false);
    } finally {
      _apiClient.setAccessToken(null);
      await _tokenStorage?.clearSession();
    }
  }
}
