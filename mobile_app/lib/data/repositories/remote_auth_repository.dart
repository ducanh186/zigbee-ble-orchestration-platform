import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/api_client.dart';

// TODO(SCRUM-20): Cloud backend does not yet expose an auth router.
// Expected contract once implemented:
//   POST /auth/login  body: {"username": "...", "password": "..."}
//   200 -> {"access_token": "...", "user_id": "...", "expires_at": "<ISO8601>"}
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
        message: 'Auth response missing access_token',
      );
    }
    final userId = map['user_id'] as String?;
    final expiresAtRaw = map['expires_at'] as String?;
    return AuthSession(
      accessToken: rawAccessToken,
      userId: userId,
      expiresAt: expiresAtRaw == null ? null : DateTime.tryParse(expiresAtRaw),
    );
  }

  @override
  Future<void> logout() async {
    await _apiClient.postJson('/auth/logout', <String, Object?>{});
  }
}
