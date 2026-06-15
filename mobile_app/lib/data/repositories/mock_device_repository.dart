import 'dart:async';

import '../../domain/models/command_result.dart';
import '../../domain/models/command_status.dart';
import '../../domain/models/cloud_status.dart';
import '../../domain/models/device_power.dart';
import '../../domain/models/event_log.dart';
import '../../domain/models/room.dart';
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
      deviceType: 'sensor',
      sensorKind: 1,
      name: 'Lab Motion',
      roomId: 'lab01',
      isOnline: true,
      power: DevicePower.unknown,
      reportedAt: '07:16 05/07/2026',
      state: {'occupancy': 'occupied'},
    ),
    const SmartDevice(
      id: 'switch-01',
      deviceType: 'switch',
      name: 'Lobby Switch',
      roomId: 'lobby',
      isOnline: true,
      power: DevicePower.unknown,
      reportedAt: '07:15 05/07/2026',
    ),
    const SmartDevice(
      id: 'environment-01',
      deviceType: 'sensor',
      sensorKind: 2,
      name: 'DHT11 Sensor',
      roomId: 'lab01',
      isOnline: true,
      power: DevicePower.unknown,
      reportedAt: '07:16 05/07/2026',
      state: {
        'temperature_c': 28.5,
        'humidity_percent': 48,
        'sensor': 'dht11',
        'reachable': true,
      },
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
    const EventLog(
      id: '3',
      deviceId: 'pir-01',
      eventType: 'occupancy_changed',
      message: 'occupied',
      occurredAt: '07:13 05/07/2026',
      source: 'gateway',
    ),
    const EventLog(
      id: '4',
      deviceId: 'switch-01',
      eventType: 'toggle',
      message: 'toggle',
      occurredAt: '07:12 05/07/2026',
      source: 'gateway',
    ),
  ];

  final List<Room> _rooms = [
    Room(id: 'lab01', name: 'Lab 01'),
    Room(id: 'lobby', name: 'Lobby'),
    Room(id: 'floor2', name: 'Floor 2'),
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
  Future<List<Room>> fetchRooms() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return List.unmodifiable(_rooms);
  }

  @override
  Future<Room> createRoom(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final room = Room(
      id: 'room-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
    );
    _rooms.add(room);
    return room;
  }

  @override
  Future<Room> renameRoom({
    required String roomId,
    required String name,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final index = _rooms.indexWhere((room) => room.id == roomId);
    final room = Room(id: roomId, name: name);
    if (index != -1) {
      _rooms[index] = room;
    }
    return room;
  }

  @override
  Future<Room> deleteRoom(String roomId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final index = _rooms.indexWhere((room) => room.id == roomId);
    if (index == -1) {
      return Room(id: roomId, name: roomId);
    }
    final room = _rooms.removeAt(index);
    return room;
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
  Future<SmartDevice> renameDeviceName({
    required String deviceId,
    required String name,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final index = _devices.indexWhere((device) => device.id == deviceId);
    if (index == -1) {
      return SmartDevice(
        id: deviceId,
        deviceType: 'unknown',
        name: name,
        isOnline: false,
        power: DevicePower.unknown,
      );
    }
    _devices[index] = _devices[index].copyWith(name: name);
    return _devices[index];
  }

  @override
  Future<SmartDevice> moveDeviceToRoom({
    required String deviceId,
    required String roomId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final index = _devices.indexWhere((device) => device.id == deviceId);
    if (index == -1) {
      return SmartDevice(
        id: deviceId,
        deviceType: 'unknown',
        name: deviceId,
        isOnline: false,
        power: DevicePower.unknown,
        roomId: roomId,
      );
    }
    _devices[index] = _devices[index].copyWith(roomId: roomId);
    return _devices[index];
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
