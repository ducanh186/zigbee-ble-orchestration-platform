import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/domain/models/command_result.dart';
import 'package:zigbee_smart_building/domain/models/command_status.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/domain/models/device_power.dart';
import 'package:zigbee_smart_building/domain/models/event_log.dart';
import 'package:zigbee_smart_building/domain/models/smart_device.dart';
import 'package:zigbee_smart_building/domain/repositories/device_repository.dart';
import 'package:zigbee_smart_building/ui/features/devices/view_models/device_dashboard_view_model.dart';

void main() {
  test(
    'setLightPower sends command for stale light with known power',
    () async {
      final repository = _CommandCaptureRepository();
      final viewModel = DeviceDashboardViewModel(repository: repository);
      const staleLight = SmartDevice(
        id: '0000000000000055',
        deviceType: 'light',
        name: 'Lab Light That',
        isOnline: false,
        power: DevicePower.on,
        roomId: 'room-01',
      );

      await viewModel.setLightPower(staleLight, DevicePower.off);

      expect(repository.sentDeviceId, staleLight.id);
      expect(repository.sentTarget, DevicePower.off);
      expect(viewModel.lastCommand?.status, CommandStatus.accepted);
    },
  );
}

class _CommandCaptureRepository implements DeviceRepository {
  String? sentDeviceId;
  DevicePower? sentTarget;

  @override
  Future<CloudStatus> fetchCloudStatus() async => const CloudStatus.online();

  @override
  Future<List<SmartDevice>> fetchDevices() async => const <SmartDevice>[];

  @override
  Future<List<EventLog>> fetchEvents({String? deviceId}) async =>
      const <EventLog>[];

  @override
  Future<CommandResult> sendLightPowerCommand({
    required String deviceId,
    required DevicePower target,
  }) async {
    sentDeviceId = deviceId;
    sentTarget = target;
    return CommandResult(
      id: 'pending',
      deviceId: deviceId,
      status: CommandStatus.accepted,
    );
  }

  @override
  Future<SmartDevice> renameDeviceName({
    required String deviceId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CommandResult> fetchCommand(String commandId) {
    throw UnimplementedError();
  }
}
