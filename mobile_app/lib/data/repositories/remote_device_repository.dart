import '../../domain/models/command_result.dart';
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
  Future<List<SmartDevice>> fetchDevices() async {
    final json = await _apiClient.getJson('/api/devices');
    final devices = (json as List)
        .whereType<Map>()
        .map((item) => DeviceApiModel.fromJson(Map<String, Object?>.from(item)))
        .toList();

    final resolved = <SmartDevice>[];
    for (final device in devices) {
      if (device.deviceType != 'light') {
        resolved.add(device.toDomain());
        continue;
      }

      try {
        final stateJson = await _apiClient.getJson(
          '/api/devices/${device.id}/state',
        );
        final state = DeviceStateApiModel.fromJson(
          Map<String, Object?>.from(stateJson as Map),
        );
        resolved.add(
          device.toDomain(power: state.power, reportedAt: state.reportedAt),
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
        : '?device_id=$deviceId&limit=30';
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
  Future<CommandResult> fetchCommand(String commandId) async {
    final json = await _apiClient.getJson('/api/commands/$commandId');
    return CommandApiModel.fromJson(
      Map<String, Object?>.from(json as Map),
    ).toDomain();
  }
}
