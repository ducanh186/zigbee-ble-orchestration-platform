import '../models/provisioning_session.dart';

abstract class ProvisioningRepository {
  Future<ProvisioningSession> createSession({
    required String gatewayId,
    required String roomId,
    required ProvisioningQrPayload payload,
  });

  Future<ProvisioningSession> fetchSession(String sessionId);

  Future<ProvisioningSession> cancelSession(String sessionId);

  Stream<ProvisioningSession> pollSession(
    String sessionId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  });
}
