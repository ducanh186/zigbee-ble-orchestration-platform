import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/api_client.dart';

// TODO(SCRUM-20): Cloud backend does not yet expose an auth router.
// Expected contract once implemented:
//   POST /auth/login  body: {"username": "...", "password": "..."}
//   200 -> {"access_token": "...", "user_id": "...", "role": "...",
//           "home_id": "...", "expires_at": "<ISO8601>"}
//   POST /auth/logout (authenticated)
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final json = await _apiClient.postJson('/auth/login', <String, Object?>{
      'username': username,
      'password': password,
    });
    final map = Map<String, Object?>.from(json as Map);
    final rawAccessToken = map['access_token'];
    if (rawAccessToken is! String || rawAccessToken.isEmpty) {
      throw const ApiException(
        statusCode: 200,
        kind: ApiErrorKind.unknown,
        message: 'Auth response missing access_token',
      );
    }
    final userId = map['user_id'] as String?;
    final role = map['role'] as String?;
    final homeId = map['home_id'] as String?;
    final expiresAtRaw = map['expires_at'] as String?;
    final session = AuthSession(
      accessToken: rawAccessToken,
      userId: userId,
      role: role,
      homeId: homeId,
      expiresAt: expiresAtRaw == null ? null : DateTime.tryParse(expiresAtRaw),
    );

    // SCRUM-29: wire the bearer token into the shared ApiClient so
    // subsequent authenticated calls (devices, automation, logs) carry it.
    // Owning this side effect in the repository keeps the view model free
    // of API-client knowledge.
    _apiClient.setAccessToken(session.accessToken);

    return session;
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.postJson('/auth/logout', <String, Object?>{});
    } finally {
      // Always clear the token locally even if the server call fails so the
      // client cannot accidentally reuse a revoked bearer.
      _apiClient.setAccessToken(null);
    }
  }
}
