import '../../domain/models/device_power.dart';
import '../../domain/models/occupancy_state.dart';
import '../../domain/models/smart_device.dart';

class DeviceApiModel {
  const DeviceApiModel({
    required this.id,
    required this.deviceType,
    required this.isOnline,
    this.eui64,
    this.roomId,
    this.name,
  });

  factory DeviceApiModel.fromJson(Map<String, Object?> json) {
    return DeviceApiModel(
      id: json['id'] as String,
      deviceType: json['device_type'] as String,
      eui64: json['eui64'] as String?,
      roomId: json['room_id'] as String?,
      name: json['name'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
    );
  }

  final String id;
  final String deviceType;
  final String? eui64;
  final String? roomId;
  final String? name;
  final bool isOnline;

  SmartDevice toDomain({
    DevicePower power = DevicePower.unknown,
    String? reportedAt,
    OccupancyState? occupancy,
  }) {
    return SmartDevice(
      id: id,
      deviceType: deviceType,
      eui64: eui64,
      roomId: roomId,
      name: name == null || name!.isEmpty ? id : name!,
      isOnline: isOnline,
      power: power,
      reportedAt: reportedAt,
      occupancy: occupancy,
    );
  }
}
