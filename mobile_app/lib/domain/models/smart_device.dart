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
    this.sensorKind,
    this.reportedAt,
    this.state = const <String, Object?>{},
  });

  final String id;
  final String deviceType;
  final String name;
  final String? eui64;
  final String? roomId;

  /// Device-model-v2 sensor slot: 1 = occupancy, 2 = environment (temp/humi).
  /// Null for non-sensor devices and legacy rows.
  final int? sensorKind;
  final bool isOnline;
  final DevicePower power;
  final String? reportedAt;
  final Map<String, Object?> state;

  bool get isLight => deviceType == 'light';
  // Device-model-v2 unifies sensors under deviceType 'sensor' + sensorKind;
  // the legacy 'motion'/'environment' types are still read for rows that
  // predate the cloud migration (dual-read during rollout).
  bool get isMotion =>
      deviceType == 'sensor' ? sensorKind == 1 : deviceType == 'motion';
  bool get isEnvironment =>
      deviceType == 'sensor' ? sensorKind == 2 : deviceType == 'environment';
  bool get isReachable => isOnline && power != DevicePower.unreachable;
  double? get temperatureC => (state['temperature_c'] as num?)?.toDouble();
  double? get humidityPercent =>
      (state['humidity_percent'] as num?)?.toDouble();

  /// Free-form sensor model label from reported state (e.g. "dht11").
  String? get sensorLabel => state['sensor']?.toString();
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
    int? sensorKind,
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
      sensorKind: sensorKind ?? this.sensorKind,
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
