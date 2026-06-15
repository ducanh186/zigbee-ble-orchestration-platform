import '../../domain/models/provisioning_session.dart';
import '../../domain/repositories/provisioning_repository.dart';

class MockProvisioningRepository implements ProvisioningRepository {
  @override
  Future<ProvisioningSession> createSession({
    required String gatewayId,
    required ProvisioningQrPayload payload,
    String? roomId,
  }) async {
    return _session(
      status: ProvisioningStatus.pending,
      gatewayId: gatewayId,
      roomId: roomId,
      payload: payload,
    );
  }

  @override
  Future<ProvisioningSession> assignSessionRoom({
    required String sessionId,
    required String roomId,
  }) async {
    return _session(status: ProvisioningStatus.pending, roomId: roomId);
  }

  @override
  Future<ProvisioningSession> fetchSession(String sessionId) async {
    return _session(status: ProvisioningStatus.permitOpen);
  }

  @override
  Future<ProvisioningSession> cancelSession(String sessionId) async {
    return _session(status: ProvisioningStatus.cancelled);
  }

  @override
  Stream<ProvisioningSession> pollSession(
    String sessionId, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) {
    return Stream.fromIterable([
      _session(status: ProvisioningStatus.permitOpen),
      _session(status: ProvisioningStatus.joined),
    ]);
  }

  ProvisioningSession _session({
    required ProvisioningStatus status,
    String gatewayId = 'gw-ubuntu-01',
    String? roomId = 'lab',
    ProvisioningQrPayload? payload,
  }) {
    return ProvisioningSession(
      sessionId: 'mock-provisioning-session',
      status: status,
      gatewayId: gatewayId,
      roomId: roomId,
      eui64: payload?.eui64 ?? 'A8D417FEFF570B00',
      deviceType: payload?.deviceType ?? ProvisioningDeviceType.light,
      model: payload?.model ?? 'EFR32MG12_LIGHT_KIT',
    );
  }
}
