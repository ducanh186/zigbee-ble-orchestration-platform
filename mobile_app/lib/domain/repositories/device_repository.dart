import '../../data/models/device_state_api_model.dart';
import '../models/command_result.dart';
import '../models/cloud_status.dart';
import '../models/device_power.dart';
import '../models/event_log.dart';
import '../models/smart_device.dart';

abstract class DeviceRepository {
  Future<CloudStatus> fetchCloudStatus();

  Future<List<SmartDevice>> fetchDevices();

  Future<List<EventLog>> fetchEvents({String? deviceId});

  Future<CommandResult> sendLightPowerCommand({
    required String deviceId,
    required DevicePower target,
  });

  Future<CommandResult> fetchCommand(String commandId);

  /// Fetches the latest reported state for the given [deviceIds] from the
  /// cloud per-device state endpoint (`GET /api/devices/{id}/state`).
  ///
  /// Devices whose state endpoint returns 404 (no state ever reported) are
  /// silently skipped. Any other transport / HTTP error is rethrown so callers
  /// can decide whether to surface it.
  Future<List<DeviceStateApiModel>> refreshDeviceStates(List<String> deviceIds);
}
