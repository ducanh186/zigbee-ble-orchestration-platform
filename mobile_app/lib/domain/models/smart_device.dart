import 'device_power.dart';

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
    this.state = const <String, Object?>{},
  });

  final String id;
  final String deviceType;
  final String name;
  final String? eui64;
  final String? roomId;
  final bool isOnline;
  final DevicePower power;
  final String? reportedAt;
  final Map<String, Object?> state;

  bool get isLight => deviceType == 'light';
  bool get isMotion => deviceType == 'motion';
  bool get isReachable => isOnline && power != DevicePower.unreachable;
  String get roomLabel =>
      roomId == null || roomId!.isEmpty ? 'No room' : roomId!;
  OccupancyState get occupancy => OccupancyState.fromValue(
    state['occupancy'] ?? state['occupied'] ?? state['motion'],
  );

  SmartDevice copyWith({
    String? id,
    String? deviceType,
    String? name,
    String? eui64,
    String? roomId,
    bool? isOnline,
    DevicePower? power,
    String? reportedAt,
    Map<String, Object?>? state,
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
      state: state ?? this.state,
    );
  }
}

enum OccupancyState {
  occupied('OCCUPIED'),
  unoccupied('UNOCCUPIED'),
  unknown('UNKNOWN');

  const OccupancyState(this.label);

  final String label;

  static OccupancyState fromValue(Object? value) {
    if (value is bool) {
      return value ? occupied : unoccupied;
    }
    if (value is num) {
      if (value == 1) {
        return occupied;
      }
      if (value == 0) {
        return unoccupied;
      }
    }

    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'occupied' || 'true' || '1' || 'motion' || 'detected' => occupied,
      'unoccupied' || 'false' || '0' || 'clear' || 'idle' => unoccupied,
      _ => unknown,
    };
  }
}
