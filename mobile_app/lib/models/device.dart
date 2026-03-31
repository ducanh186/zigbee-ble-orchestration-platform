/// Model representing a Zigbee/BLE device.
///
/// Mirrors the cloud API's `DeviceOut` schema.
class Device {
  const Device({
    required this.id,
    required this.deviceType,
    this.eui64,
    this.roomId,
    this.name,
    required this.isOnline,
    this.createdAt,
    this.updatedAt,
  });

  /// Logical stable device identifier (primary key).
  final String id;

  /// Device type (e.g. "light", "switch", "sensor").
  final String deviceType;

  /// Hardware EUI-64 identifier.
  final String? eui64;

  /// Room this device belongs to (nullable).
  final String? roomId;

  /// Human-readable device name.
  final String? name;

  /// Whether the device is currently online.
  final bool isOnline;

  /// Timestamp when the device record was created.
  final DateTime? createdAt;

  /// Timestamp when the device record was last updated.
  final DateTime? updatedAt;

  /// Create a [Device] from a JSON map returned by the cloud API.
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      deviceType: json['device_type'] as String,
      eui64: json['eui64'] as String?,
      roomId: json['room_id'] as String?,
      name: json['name'] as String?,
      isOnline: json['is_online'] as bool,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Serialize this device to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_type': deviceType,
      'eui64': eui64,
      'room_id': roomId,
      'name': name,
      'is_online': isOnline,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'Device(id: $id, name: $name, type: $deviceType)';
}
