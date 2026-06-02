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
  RemoteDeviceRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<CloudStatus> fetchCloudStatus() async {
    try {
      final json = await _apiClient.getJson('/api/events/?limit=50');
      final events = (json as List).whereType<Map>();
      for (final rawEvent in events) {
        final status = _gatewayStatusFromEvent(
          Map<String, Object?>.from(rawEvent),
        );
        if (status != null) {
          return status;
        }
      }
      return const CloudStatus.unknown(
        detail: 'No home hub status log found in cloud events',
      );
    } catch (error) {
      return CloudStatus.unknown(
        detail: 'Cannot read cloud event logs: $error',
      );
    }
  }

  CloudStatus? _gatewayStatusFromEvent(Map<String, Object?> event) {
    final eventType = event['event_type']?.toString() ?? '';
    final payloadRaw = event['payload'];
    final payload = payloadRaw is Map
        ? Map<String, Object?>.from(payloadRaw)
        : const <String, Object?>{};
    final payloadEvent = payload['event']?.toString() ?? '';
    final source = payload['source']?.toString();
    final hasGatewayMarker =
        eventType.startsWith('gateway_') ||
        payloadEvent.startsWith('gateway_') ||
        payload.containsKey('gateway_id') ||
        source == 'gateway' && event['device_id'] == null;

    if (!hasGatewayMarker) {
      return null;
    }

    final value = (payload['value'] ?? payload['status'] ?? payload['state'])
        ?.toString()
        .toLowerCase();
    final gatewayId = payload['gateway_id']?.toString();
    final occurredAt = event['occurred_at']?.toString();
    final resolvedEventType = eventType.isEmpty ? payloadEvent : eventType;

    if (value == 'online') {
      return CloudStatus.online(
        gatewayId: gatewayId,
        eventType: resolvedEventType,
        occurredAt: occurredAt,
      );
    }
    if (value == 'offline') {
      return CloudStatus.offline(
        detail: 'Home hub reported offline',
        gatewayId: gatewayId,
        eventType: resolvedEventType,
        occurredAt: occurredAt,
      );
    }

    return CloudStatus.unknown(
      detail: value ?? 'Home hub log has no status value',
      gatewayId: gatewayId,
      eventType: resolvedEventType,
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
