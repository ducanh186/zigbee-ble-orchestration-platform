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

  Future<SmartDevice> renameDeviceName({
    required String deviceId,
    required String name,
  });

  Future<CommandResult> fetchCommand(String commandId);
}
