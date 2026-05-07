import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../domain/models/command_result.dart';
import '../../../../domain/models/command_status.dart';
import '../../../../domain/models/cloud_status.dart';
import '../../../../domain/models/device_power.dart';
import '../../../../domain/models/event_log.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../../domain/repositories/device_repository.dart';

class DeviceDashboardViewModel extends ChangeNotifier {
  DeviceDashboardViewModel({required DeviceRepository repository})
    : _repository = repository;

  final DeviceRepository _repository;

  List<SmartDevice> _devices = [];
  List<EventLog> _events = [];
  bool _isLoading = false;
  String? _errorMessage;
  CloudStatus _cloudStatus = const CloudStatus.unknown(
    detail: 'Not checked yet',
  );
  CommandResult? _lastCommand;
  DevicePower? _lastTarget;

  List<SmartDevice> get devices => List.unmodifiable(_devices);
  List<SmartDevice> get lights =>
      _devices.where((device) => device.isLight).toList(growable: false);
  List<EventLog> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  CloudStatus get cloudStatus => _cloudStatus;
  CommandResult? get lastCommand => _lastCommand;
  DevicePower? get lastTarget => _lastTarget;

  int get onlineCount => _devices.where((device) => device.isOnline).length;
  int get lightsOnCount =>
      lights.where((device) => device.power == DevicePower.on).length;
  int get unreachableCount =>
      lights.where((device) => !device.isReachable).length;
  bool get hasPendingCommand => _lastCommand?.status.isPending ?? false;

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
      _cloudStatus = await _repository.fetchCloudStatus();
      final devices = await _repository.fetchDevices();
      final events = await _repository.fetchEvents();
      _devices = devices;
      _events = events;
    } catch (error) {
      _cloudStatus = CloudStatus.unknown(detail: error.toString());
      _errorMessage =
          'Khong ket noi duoc Cloud API. Kiem tra server hoac mang. $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setLightPower(SmartDevice device, DevicePower target) async {
    if (!device.isLight || !device.isReachable || hasPendingCommand) {
      return;
    }

    _lastTarget = target;
    _lastCommand = CommandResult(
      id: 'pending',
      deviceId: device.id,
      status: CommandStatus.accepted,
    );
    _errorMessage = null;
    notifyListeners();

    try {
      _lastCommand = await _repository.sendLightPowerCommand(
        deviceId: device.id,
        target: target,
      );
      notifyListeners();

      await _pollCommand(target);
      await load();
    } catch (error) {
      _lastCommand = CommandResult(
        id: _lastCommand?.id ?? 'unknown',
        deviceId: device.id,
        status: CommandStatus.failed,
        reason: error.toString(),
      );
      _errorMessage = error.toString();
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

  Future<void> _pollCommand(DevicePower target) async {
    final commandId = _lastCommand?.id;
    if (commandId == null || commandId == 'pending') {
      return;
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final command = await _repository.fetchCommand(commandId);
      _lastCommand = command;

      if (command.status == CommandStatus.executed) {
        _applyPower(command.deviceId, target);
      }

      notifyListeners();
      if (command.status.isTerminal) {
        return;
      }
    }

    _lastCommand = CommandResult(
      id: commandId,
      deviceId: _lastCommand?.deviceId ?? '',
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
