import 'dart:async';

import '../../domain/models/command_result.dart';
import '../../domain/models/command_status.dart';
import '../../domain/models/cloud_status.dart';
import '../../domain/models/device_power.dart';
import '../../domain/models/event_log.dart';
import '../../domain/models/smart_device.dart';
import '../../domain/repositories/device_repository.dart';

class MockDeviceRepository implements DeviceRepository {
  final List<SmartDevice> _devices = [
    const SmartDevice(
      id: 'light-01',
      deviceType: 'light',
      name: 'Lab Light 01',
      roomId: 'lab01',
      isOnline: true,
      power: DevicePower.on,
      reportedAt: '07:16 05/07/2026',
    ),
    const SmartDevice(
      id: 'light-02',
      deviceType: 'light',
      name: 'Hallway Light',
      roomId: 'lobby',
      isOnline: true,
      power: DevicePower.off,
      reportedAt: '07:14 05/07/2026',
    ),
    const SmartDevice(
      id: 'light-03',
      deviceType: 'light',
      name: 'Stairwell B',
      roomId: 'floor2',
      isOnline: false,
      power: DevicePower.unreachable,
      reportedAt: '06:52 05/07/2026',
    ),
    const SmartDevice(
      id: 'pir-01',
      deviceType: 'motion',
      name: 'Lab Motion',
      roomId: 'lab01',
      isOnline: true,
      power: DevicePower.unknown,
      reportedAt: '07:16 05/07/2026',
    ),
  ];

  final List<EventLog> _events = [
    const EventLog(
      id: '1',
      deviceId: 'light-01',
      eventType: 'LIGHT',
      message: 'State reported: on',
      occurredAt: '07:16 05/07/2026',
      source: 'gateway',
    ),
    const EventLog(
      id: '2',
      deviceId: 'light-02',
      eventType: 'LIGHT',
      message: 'Command executed: off',
      occurredAt: '07:14 05/07/2026',
      source: 'gateway',
      commandId: 'cmd-demo',
    ),
  ];

  final Map<String, _MockCommand> _commands = {};
  int _nextCommand = 10;

  @override
  Future<CloudStatus> fetchCloudStatus() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return const CloudStatus.mock();
  }

  @override
  Future<List<SmartDevice>> fetchDevices() async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return List.unmodifiable(_devices);
  }

  @override
  Future<List<EventLog>> fetchEvents({String? deviceId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final events = deviceId == null
        ? _events
        : _events.where((event) => event.deviceId == deviceId);
    return List.unmodifiable(events);
  }

  @override
  Future<CommandResult> sendLightPowerCommand({
    required String deviceId,
    required DevicePower target,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final id = 'cmd-${_nextCommand++}';
    _commands[id] = _MockCommand(
      id: id,
      deviceId: deviceId,
      target: target,
      createdAt: DateTime.now(),
    );
    return CommandResult(
      id: id,
      deviceId: deviceId,
      status: CommandStatus.accepted,
    );
  }

  @override
  Future<CommandResult> fetchCommand(String commandId) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final command = _commands[commandId];
    if (command == null) {
      return CommandResult(
        id: commandId,
        deviceId: '',
        status: CommandStatus.failed,
        reason: 'Command not found',
      );
    }

    final elapsed = DateTime.now().difference(command.createdAt);
    if (elapsed > const Duration(milliseconds: 900)) {
      _applyCommand(command);
      return CommandResult(
        id: command.id,
        deviceId: command.deviceId,
        status: CommandStatus.executed,
      );
    }

    return CommandResult(
      id: command.id,
      deviceId: command.deviceId,
      status: elapsed > const Duration(milliseconds: 450)
          ? CommandStatus.sent
          : CommandStatus.queued,
    );
  }

  void _applyCommand(_MockCommand command) {
    final index = _devices.indexWhere(
      (device) => device.id == command.deviceId,
    );
    if (index == -1) {
      return;
    }
    _devices[index] = _devices[index].copyWith(
      power: command.target,
      isOnline: true,
      reportedAt: 'now',
    );
    _events.insert(
      0,
      EventLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        deviceId: command.deviceId,
        eventType: 'LIGHT',
        message: 'Command executed: ${command.target.wireValue}',
        occurredAt: 'now',
        source: 'gateway',
        commandId: command.id,
      ),
    );
  }
}

class _MockCommand {
  const _MockCommand({
    required this.id,
    required this.deviceId,
    required this.target,
    required this.createdAt,
  });

  final String id;
  final String deviceId;
  final DevicePower target;
  final DateTime createdAt;
}
