import '../../domain/models/device_power.dart';

class DeviceStateApiModel {
  const DeviceStateApiModel({
    required this.deviceId,
    required this.power,
    required this.state,
    this.reportedAt,
  });

  factory DeviceStateApiModel.fromJson(Map<String, Object?> json) {
    final stateRaw = json['state'];
    final state = stateRaw is Map
        ? Map<String, Object?>.from(stateRaw)
        : const <String, Object?>{};
    final reachable = state['reachable'] as bool? ?? true;

    return DeviceStateApiModel(
      deviceId: json['device_id'] as String,
      power: DevicePower.fromJson(state['power'], reachable: reachable),
      state: state,
      reportedAt: json['reported_at'] as String?,
    );
  }

  final String deviceId;
  final DevicePower power;
  final Map<String, Object?> state;
  final String? reportedAt;
}
