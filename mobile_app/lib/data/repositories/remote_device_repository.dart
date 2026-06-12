import '../../domain/models/command_result.dart';
import '../../domain/models/cloud_status.dart';
import '../../domain/models/device_power.dart';
import '../../domain/models/event_log.dart';
import '../../domain/models/smart_device.dart';
import '../../domain/repositories/device_repository.dart';
import '../models/command_api_model.dart';
import '../models/device_api_model.dart';
import '../models/device_state_api_model.dart';
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
      final json = await _apiClient.getJson(
        '/api/gateways/$gatewayId/status',
      );
      return _gatewayStatusFromJson(
        Map<String, Object?>.from(json as Map),
      );
    } catch (error) {
      return CloudStatus.unknown(
        detail: 'Cannot read home hub status: $error',
      );
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
    final json = await _apiClient.getJson('/api/devices/');
    final devices = (json as List)
        .whereType<Map>()
        .map((item) => DeviceApiModel.fromJson(Map<String, Object?>.from(item)))
        .toList();

    final resolved = <SmartDevice>[];
    for (final device in devices) {
      try {
        final stateJson = await _apiClient.getJson(
          '/api/devices/${device.id}/state',
        );
        final state = DeviceStateApiModel.fromJson(
          Map<String, Object?>.from(stateJson as Map),
        );
        resolved.add(
          device.toDomain(
            power: state.power,
            reportedAt: state.reportedAt,
            state: state.state,
          ),
        );
      } on ApiException catch (error) {
        if (error.statusCode == 404) {
          resolved.add(device.toDomain());
          continue;
        }
        rethrow;
      }
    }

    return resolved;
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
  Future<CommandResult> fetchCommand(String commandId) async {
    final json = await _apiClient.getJson('/api/commands/$commandId');
    return CommandApiModel.fromJson(
      Map<String, Object?>.from(json as Map),
    ).toDomain();
  }
}
