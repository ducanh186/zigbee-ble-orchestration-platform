import 'device_power.dart';
import 'occupancy_state.dart';

class SmartDevice {
  const SmartDevice({
    required this.id,
    required this.deviceType,
    required this.name,
    required this.isOnline,
    required this.power,
    this.eui64,
    this.roomId,
    this.reportedAt,
    this.occupancy,
  });

  final String id;
  final String deviceType;
  final String name;
  final String? eui64;
  final String? roomId;
  final bool isOnline;
  final DevicePower power;
  final String? reportedAt;

  /// Latest reported presence/occupancy for motion sensors. `null` for
  /// non-motion devices and for motion devices that have not yet reported.
  final OccupancyState? occupancy;

  bool get isLight => deviceType == 'light';
  bool get isMotion => deviceType == 'motion';
  bool get isReachable => isOnline && power != DevicePower.unreachable;
  String get roomLabel =>
      roomId == null || roomId!.isEmpty ? 'No room' : roomId!;

  SmartDevice copyWith({
    String? id,
    String? deviceType,
    String? name,
    String? eui64,
    String? roomId,
    bool? isOnline,
    DevicePower? power,
    String? reportedAt,
    OccupancyState? occupancy,
  }) {
    return SmartDevice(
      id: id ?? this.id,
      deviceType: deviceType ?? this.deviceType,
      name: name ?? this.name,
      eui64: eui64 ?? this.eui64,
      roomId: roomId ?? this.roomId,
      isOnline: isOnline ?? this.isOnline,
      power: power ?? this.power,
      reportedAt: reportedAt ?? this.reportedAt,
      occupancy: occupancy ?? this.occupancy,
    );
  }
}
