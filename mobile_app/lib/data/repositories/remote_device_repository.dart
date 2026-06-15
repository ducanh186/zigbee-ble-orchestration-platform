import '../../domain/models/command_result.dart';
import '../../domain/models/cloud_status.dart';
import '../../domain/models/device_power.dart';
import '../../domain/models/event_log.dart';
import '../../domain/models/room.dart';
import '../../domain/models/smart_device.dart';
import '../../domain/repositories/device_repository.dart';
import '../models/command_api_model.dart';
import '../models/device_api_model.dart';
import '../models/event_api_model.dart';
import '../services/api_client.dart';

class RemoteDeviceRepository implements DeviceRepository {
  RemoteDeviceRepository({
    required ApiClient apiClient,
    this.gatewayId = 'gw-ubuntu-01',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String gatewayId;

  @override
  Future<CloudStatus> fetchCloudStatus() async {
    try {
      final json = await _apiClient.getJson('/api/gateways/$gatewayId/status');
      return _gatewayStatusFromJson(Map<String, Object?>.from(json as Map));
    } catch (error) {
      return CloudStatus.unknown(detail: 'Cannot read home hub status: $error');
    }
  }

  CloudStatus _gatewayStatusFromJson(Map<String, Object?> json) {
    final value = json['status']?.toString().toLowerCase();
    final resolvedGatewayId = json['gateway_id']?.toString();
    final eventType = json['event_type']?.toString();
    final occurredAt = json['occurred_at']?.toString();

    if (value == 'online') {
      return CloudStatus.online(
        gatewayId: resolvedGatewayId,
        eventType: eventType,
        occurredAt: occurredAt,
      );
    }
    if (value == 'offline') {
      return CloudStatus.offline(
        detail: 'Home hub reported offline',
        gatewayId: resolvedGatewayId,
        eventType: eventType,
        occurredAt: occurredAt,
      );
    }

    return CloudStatus.unknown(
      detail: 'No home hub status log found in cloud',
      gatewayId: resolvedGatewayId,
      eventType: eventType,
      occurredAt: occurredAt,
    );
  }

  @override
  Future<List<SmartDevice>> fetchDevices() async {
    // The list endpoint inlines each device's latest `state` + `reported_at`,
    // so this is a single round-trip (no per-device /state fan-out).
    final json = await _apiClient.getJson('/api/devices/');
    return (json as List).whereType<Map>().map((item) {
      final map = Map<String, Object?>.from(item);
      final model = DeviceApiModel.fromJson(map);
      final reachable = model.state['reachable'] as bool? ?? true;
      final power = DevicePower.fromJson(
        model.state['power'],
        reachable: reachable,
      );
      return model.toDomain(
        power: power,
        reportedAt: map['reported_at'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<Room>> fetchRooms() async {
    final json = await _apiClient.getJson('/api/rooms/');
    return (json as List)
        .whereType<Map>()
        .map((item) => _roomFromJson(Map<String, Object?>.from(item)))
        .toList();
  }

  @override
  Future<Room> createRoom(String name) async {
    final json = await _apiClient.postJson('/api/rooms/', {'name': name});
    return _roomFromJson(Map<String, Object?>.from(json as Map));
  }

  @override
  Future<Room> renameRoom({
    required String roomId,
    required String name,
  }) async {
    final json = await _apiClient.patchJson('/api/rooms/$roomId', {
      'name': name,
    });
    return _roomFromJson(Map<String, Object?>.from(json as Map));
  }

  @override
  Future<Room> deleteRoom(String roomId) async {
    final json = await _apiClient.deleteJson('/api/rooms/$roomId');
    return _roomFromJson(Map<String, Object?>.from(json as Map));
  }

  Room _roomFromJson(Map<String, Object?> json) {
    final id = json['id'] as String;
    return Room(id: id, name: (json['name'] as String?) ?? id);
  }

  @override
  Future<List<EventLog>> fetchEvents({String? deviceId}) async {
    final query = deviceId == null
        ? '?limit=30'
        : '?device_id=$deviceId&limit=3';
    final json = await _apiClient.getJson('/api/events/$query');
    return (json as List)
        .whereType<Map>()
        .map((item) => EventApiModel.fromJson(Map<String, Object?>.from(item)))
        .map((model) => model.toDomain())
        .toList();
  }

  @override
  Future<CommandResult> sendLightPowerCommand({
    required String deviceId,
    required DevicePower target,
  }) async {
    final json = await _apiClient.postJson('/api/devices/$deviceId/command', {
      'op': 'set_power',
      'target': {'power': target.wireValue},
      'timeout_ms': 5000,
    });
    return CommandApiModel.fromJson(
      Map<String, Object?>.from(json as Map),
    ).toDomain();
  }

  @override
  Future<SmartDevice> renameDeviceName({
    required String deviceId,
    required String name,
  }) async {
    final json = await _apiClient.patchJson('/api/devices/$deviceId', {
      'name': name,
    });
    return DeviceApiModel.fromJson(
      Map<String, Object?>.from(json as Map),
    ).toDomain();
  }

  @override
  Future<SmartDevice> moveDeviceToRoom({
    required String deviceId,
    required String roomId,
  }) async {
    final json = await _apiClient.patchJson('/api/devices/$deviceId', {
      'room_id': roomId,
    });
    return DeviceApiModel.fromJson(
      Map<String, Object?>.from(json as Map),
    ).toDomain();
  }

  @override
  Future<CommandResult> fetchCommand(String commandId) async {
    final json = await _apiClient.getJson('/api/commands/$commandId');
    return CommandApiModel.fromJson(
      Map<String, Object?>.from(json as Map),
    ).toDomain();
  }
}
