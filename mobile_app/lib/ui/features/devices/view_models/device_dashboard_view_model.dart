import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/services/api_client.dart';
import '../../../../domain/models/command_result.dart';
import '../../../../domain/models/command_status.dart';
import '../../../../domain/models/cloud_status.dart';
import '../../../../domain/models/device_power.dart';
import '../../../../domain/models/event_log.dart';
import '../../../../domain/models/room.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../../domain/repositories/device_repository.dart';

class DeviceDashboardViewModel extends ChangeNotifier {
  DeviceDashboardViewModel({required DeviceRepository repository})
    : _repository = repository;

  final DeviceRepository _repository;

  List<SmartDevice> _devices = [];
  List<Room> _rooms = [];
  List<EventLog> _events = [];
  final Map<String, List<EventLog>> _deviceEvents = {};
  final Set<String> _loadingEventDeviceIds = {};
  final Map<String, String> _deviceEventErrors = {};
  bool _isLoading = false;
  String? _errorMessage;
  CloudStatus _cloudStatus = const CloudStatus.unknown(
    detail: 'Not checked yet',
  );
  CommandResult? _lastCommand;
  DevicePower? _lastTarget;
  bool _isRenamingDevice = false;
  bool _isMovingDevice = false;
  bool _isDeletingDevice = false;
  bool _isMutatingRoom = false;

  List<SmartDevice> get devices => List.unmodifiable(_devices);
  List<Room> get rooms => List.unmodifiable(_rooms);
  List<SmartDevice> get lights =>
      _devices.where((device) => device.isLight).toList(growable: false);
  List<EventLog> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  CloudStatus get cloudStatus => _cloudStatus;
  CommandResult? get lastCommand => _lastCommand;
  DevicePower? get lastTarget => _lastTarget;
  bool get isRenamingDevice => _isRenamingDevice;
  bool get isMovingDevice => _isMovingDevice;
  bool get isDeletingDevice => _isDeletingDevice;
  bool get isMutatingRoom => _isMutatingRoom;

  /// Human-readable room name for a device's [roomId], falling back to the raw
  /// id (then "No room") when the room list hasn't loaded or has no match.
  String roomNameFor(String? roomId) {
    if (roomId == null || roomId.isEmpty) {
      return 'No room';
    }
    for (final room in _rooms) {
      if (room.id == roomId) {
        return room.name;
      }
    }
    return roomId;
  }

  int get onlineCount => _devices.where((device) => device.isOnline).length;
  int get lightsOnCount =>
      lights.where((device) => device.power == DevicePower.on).length;
  int get unreachableCount =>
      lights.where((device) => !device.isReachable).length;
  bool get hasPendingCommand => _lastCommand?.status.isPending ?? false;

  List<EventLog> eventsForDevice(String deviceId) {
    return List.unmodifiable(_deviceEvents[deviceId] ?? const <EventLog>[]);
  }

  bool isLoadingDeviceEvents(String deviceId) {
    return _loadingEventDeviceIds.contains(deviceId);
  }

  String? deviceEventsError(String deviceId) {
    return _deviceEventErrors[deviceId];
  }

  SmartDevice? deviceById(String deviceId) {
    for (final device in _devices) {
      if (device.id == deviceId) {
        return device;
      }
    }
    return null;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Kick off the independent fetches together so the dashboard loads in
      // one round-trip's worth of latency instead of four sequential ones.
      // Rooms are optional metadata (a pre-v2 backend has no /api/rooms), so
      // that future carries its own fallback and never fails the load.
      final statusFuture = _repository.fetchCloudStatus();
      final devicesFuture = _repository.fetchDevices();
      final eventsFuture = _repository.fetchEvents();
      final roomsFuture = _repository.fetchRooms().then<List<Room>>(
        (rooms) => rooms,
        onError: (_) => <Room>[],
      );

      _cloudStatus = await statusFuture;
      _devices = await devicesFuture;
      _events = await eventsFuture;
      _rooms = [...await roomsFuture];
      _deviceEvents.clear();
    } catch (error) {
      _cloudStatus = CloudStatus.unknown(detail: error.toString());
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not connect to Cloud API',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDeviceEvents(String deviceId) async {
    _loadingEventDeviceIds.add(deviceId);
    _deviceEventErrors.remove(deviceId);
    notifyListeners();

    try {
      _deviceEvents[deviceId] = await _repository.fetchEvents(
        deviceId: deviceId,
      );
    } catch (error) {
      _deviceEventErrors[deviceId] = 'Cannot read cloud event logs';
    } finally {
      _loadingEventDeviceIds.remove(deviceId);
      notifyListeners();
    }
  }

  Future<void> setLightPower(SmartDevice device, DevicePower target) async {
    if (!device.isLight ||
        !device.power.canCommand ||
        target == device.power ||
        hasPendingCommand) {
      return;
    }

    final previousPower = device.power;
    _lastTarget = target;
    _lastCommand = CommandResult(
      id: 'pending',
      deviceId: device.id,
      status: CommandStatus.accepted,
    );
    _errorMessage = null;
    // Optimistic: reflect the target immediately so the button feels instant.
    // Reconciled (or reverted) once the cloud/gateway reply lands.
    _applyPower(device.id, target);
    notifyListeners();

    try {
      _lastCommand = await _repository.sendLightPowerCommand(
        deviceId: device.id,
        target: target,
      );
      notifyListeners();

      // Reconcile only this device (no full reload).
      await _pollCommand(device.id, target, previousPower);
    } catch (error) {
      _applyPower(device.id, previousPower); // revert optimistic change
      _lastCommand = CommandResult(
        id: _lastCommand?.id ?? 'unknown',
        deviceId: device.id,
        status: CommandStatus.failed,
        reason: error.toString(),
      );
      _errorMessage = friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> retryLastCommand() async {
    final command = _lastCommand;
    final target = _lastTarget;
    if (command == null || target == null || hasPendingCommand) {
      return;
    }
    final device = deviceById(command.deviceId);
    if (device == null) {
      return;
    }
    await setLightPower(device, target);
  }

  Future<void> renameDevice(SmartDevice device, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || _isRenamingDevice) {
      return;
    }

    _isRenamingDevice = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final renamed = await _repository.renameDeviceName(
        deviceId: device.id,
        name: normalizedName,
      );
      final index = _devices.indexWhere((item) => item.id == device.id);
      if (index != -1) {
        _devices[index] = _devices[index].copyWith(name: renamed.name);
      }
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not rename device',
      );
    } finally {
      _isRenamingDevice = false;
      notifyListeners();
    }
  }

  Future<void> moveDevice(SmartDevice device, String roomId) async {
    if (roomId == device.roomId || _isMovingDevice) {
      return;
    }

    _isMovingDevice = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final moved = await _repository.moveDeviceToRoom(
        deviceId: device.id,
        roomId: roomId,
      );
      final index = _devices.indexWhere((item) => item.id == device.id);
      if (index != -1) {
        _devices[index] = _devices[index].copyWith(roomId: moved.roomId);
      }
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not move device to room',
      );
    } finally {
      _isMovingDevice = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDevice(String deviceId) async {
    if (_isDeletingDevice) {
      return false;
    }

    _isDeletingDevice = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteDevice(deviceId);
      _devices = _devices.where((device) => device.id != deviceId).toList();
      _deviceEvents.remove(deviceId);
      _deviceEventErrors.remove(deviceId);
      _loadingEventDeviceIds.remove(deviceId);
      return true;
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not delete device',
      );
      return false;
    } finally {
      _isDeletingDevice = false;
      notifyListeners();
    }
  }

  Future<void> createRoom(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || _isMutatingRoom) {
      return;
    }

    _isMutatingRoom = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _repository.createRoom(normalizedName);
      _rooms = [..._rooms, created];
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not create room',
      );
    } finally {
      _isMutatingRoom = false;
      notifyListeners();
    }
  }

  Future<void> renameRoom({
    required String roomId,
    required String name,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || _isMutatingRoom) {
      return;
    }

    _isMutatingRoom = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final renamed = await _repository.renameRoom(
        roomId: roomId,
        name: normalizedName,
      );
      final index = _rooms.indexWhere((room) => room.id == roomId);
      if (index != -1) {
        _rooms[index] = renamed;
      }
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not rename room',
      );
    } finally {
      _isMutatingRoom = false;
      notifyListeners();
    }
  }

  Future<void> deleteRoom(String roomId) async {
    if (_isMutatingRoom) {
      return;
    }

    _isMutatingRoom = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deleted = await _repository.deleteRoom(roomId);
      _rooms = _rooms.where((room) => room.id != deleted.id).toList();
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Could not delete room',
      );
    } finally {
      _isMutatingRoom = false;
      notifyListeners();
    }
  }

  // Short backoff so a confirmed command settles fast and the button frees up
  // again quickly; the device already shows the optimistic state, so this only
  // reconciles / reverts. First poll is tight (gateway often replies in
  // ~150ms); it widens to cap total wait near 3s before declaring a timeout.
  static const _pollBackoffMs = [150, 300, 500, 800, 1200];

  Future<void> _pollCommand(
    String deviceId,
    DevicePower target,
    DevicePower previousPower,
  ) async {
    final commandId = _lastCommand?.id;
    if (commandId == null || commandId == 'pending') {
      // Optimistic state stands; nothing to reconcile.
      return;
    }

    for (final delayMs in _pollBackoffMs) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      final command = await _repository.fetchCommand(commandId);
      _lastCommand = command;

      if (command.status == CommandStatus.executed) {
        _applyPower(deviceId, target); // confirm
        notifyListeners();
        return;
      }
      if (command.status == CommandStatus.failed ||
          command.status == CommandStatus.timeout) {
        _applyPower(deviceId, previousPower); // revert
        notifyListeners();
        return;
      }
      notifyListeners();
    }

    // No terminal reply within the window: revert the optimistic change.
    _applyPower(deviceId, previousPower);
    _lastCommand = CommandResult(
      id: commandId,
      deviceId: deviceId,
      status: CommandStatus.timeout,
      reason: 'No reply within polling window',
    );
    notifyListeners();
  }

  void _applyPower(String deviceId, DevicePower target) {
    final index = _devices.indexWhere((device) => device.id == deviceId);
    if (index == -1) {
      return;
    }
    _devices[index] = _devices[index].copyWith(
      power: target,
      isOnline: true,
      reportedAt: 'now',
    );
  }
}
