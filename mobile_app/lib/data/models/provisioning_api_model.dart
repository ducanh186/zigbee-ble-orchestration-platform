import '../../domain/models/provisioning_session.dart';

class ProvisioningSessionCreateApiModel {
  const ProvisioningSessionCreateApiModel({
    required this.gatewayId,
    required this.roomId,
    required this.payload,
  });

  final String gatewayId;
  final String roomId;
  final ProvisioningQrPayload payload;

  Map<String, Object?> toJson() {
    final device = <String, Object?>{
      'eui64': payload.eui64,
      'device_type': payload.deviceType.wireValue,
    };

    final model = payload.model;
    if (model != null && model.isNotEmpty) {
      device['model'] = model;
    }

    return {
      'gateway_id': gatewayId,
      'room_id': roomId,
      'device': device,
    };
  }
}

class ProvisioningSessionApiModel {
  const ProvisioningSessionApiModel({
    required this.sessionId,
    required this.status,
    required this.gatewayId,
    required this.roomId,
    required this.eui64,
    required this.deviceType,
    this.model,
    this.reason,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ProvisioningSessionApiModel.fromJson(Map<String, Object?> json) {
    return ProvisioningSessionApiModel(
      sessionId: json['session_id'] as String,
      status: ProvisioningStatus.fromJson(json['status']),
      gatewayId: json['gateway_id'] as String,
      roomId: json['room_id'] as String,
      eui64: json['eui64'] as String,
      deviceType: ProvisioningDeviceType.fromJson(json['device_type']),
      model: json['model'] as String?,
      reason: json['reason'] as String?,
      expiresAt: json['expires_at'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final String sessionId;
  final ProvisioningStatus status;
  final String gatewayId;
  final String roomId;
  final String eui64;
  final ProvisioningDeviceType deviceType;
  final String? model;
  final String? reason;
  final String? expiresAt;
  final String? createdAt;
  final String? updatedAt;

  ProvisioningSession toDomain() {
    return ProvisioningSession(
      sessionId: sessionId,
      status: status,
      gatewayId: gatewayId,
      roomId: roomId,
      eui64: eui64,
      deviceType: deviceType,
      model: model,
      reason: reason,
      expiresAt: expiresAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
