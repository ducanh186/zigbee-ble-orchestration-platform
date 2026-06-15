import '../../domain/models/provisioning_session.dart';
import '../../domain/repositories/provisioning_repository.dart';
import '../models/provisioning_api_model.dart';
import '../services/api_client.dart';

class RemoteProvisioningRepository implements ProvisioningRepository {
  RemoteProvisioningRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<ProvisioningSession> createSession({
    required String gatewayId,
    required ProvisioningQrPayload payload,
    String? roomId,
  }) async {
    final json = await _apiClient.postJson(
      '/api/provisioning/sessions',
      ProvisioningSessionCreateApiModel(
        gatewayId: gatewayId,
        roomId: roomId,
        payload: payload,
      ).toJson(),
    );
    return _sessionFromJson(json);
  }

  @override
  Future<ProvisioningSession> assignSessionRoom({
    required String sessionId,
    required String roomId,
  }) async {
    final json = await _apiClient.patchJson(
      '/api/provisioning/sessions/$sessionId/room',
      {'room_id': roomId},
    );
    return _sessionFromJson(json);
  }

  @override
  Future<ProvisioningSession> fetchSession(String sessionId) async {
    final json = await _apiClient.getJson(
      '/api/provisioning/sessions/$sessionId',
    );
    return _sessionFromJson(json);
  }

  @override
  Future<ProvisioningSession> cancelSession(String sessionId) async {
    final json = await _apiClient.deleteJson(
      '/api/provisioning/sessions/$sessionId',
    );
    return _sessionFromJson(json);
  }

  @override
  Stream<ProvisioningSession> pollSession(
    String sessionId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) async* {
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      final session = await fetchSession(sessionId);
      yield session;

      if (session.isTerminal || attempt == maxAttempts - 1) {
        return;
      }
      if (interval > Duration.zero) {
        await Future<void>.delayed(interval);
      }
    }
  }

  ProvisioningSession _sessionFromJson(Object? json) {
    return ProvisioningSessionApiModel.fromJson(
      Map<String, Object?>.from(json as Map),
    ).toDomain();
  }
}
