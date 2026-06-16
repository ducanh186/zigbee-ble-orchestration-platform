import '../models/command_result.dart';
import '../models/cloud_status.dart';
import '../models/device_power.dart';
import '../models/event_log.dart';
import '../models/room.dart';
import '../models/smart_device.dart';

abstract class DeviceRepository {
  Future<CloudStatus> fetchCloudStatus();

  Future<List<SmartDevice>> fetchDevices();

  Future<List<Room>> fetchRooms();

  Future<Room> createRoom(String name);

  Future<Room> renameRoom({required String roomId, required String name});

  Future<Room> deleteRoom(String roomId);

  Future<List<EventLog>> fetchEvents({String? deviceId});

  Future<CommandResult> sendLightPowerCommand({
    required String deviceId,
    required DevicePower target,
  });

  Future<SmartDevice> renameDeviceName({
    required String deviceId,
    required String name,
  });

  Future<SmartDevice> moveDeviceToRoom({
    required String deviceId,
    required String roomId,
  });

  Future<void> deleteDevice(String deviceId);

  Future<CommandResult> fetchCommand(String commandId);
}
