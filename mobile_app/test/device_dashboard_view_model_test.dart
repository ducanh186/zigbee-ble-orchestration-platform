import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/data/models/device_state_api_model.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/domain/models/command_result.dart';
import 'package:zigbee_smart_building/domain/models/device_power.dart';
import 'package:zigbee_smart_building/domain/models/event_log.dart';
import 'package:zigbee_smart_building/domain/models/smart_device.dart';
import 'package:zigbee_smart_building/domain/repositories/device_repository.dart';
import 'package:zigbee_smart_building/ui/features/devices/view_models/device_dashboard_view_model.dart';

void main() {
  test('load populates devices from repository', () async {
    final repository = _FakeDeviceRepository(devices: _initialDevices());
    final viewModel = DeviceDashboardViewModel(
      repository: repository,
      pollInterval: null,
    );

    await viewModel.load();

    expect(viewModel.devices, hasLength(2));
    expect(viewModel.devices.first.id, 'light-01');
    expect(viewModel.devices.first.power, DevicePower.on);
    expect(viewModel.errorMessage, isNull);
  });

  test(
    'refreshDeviceStates merges fresh power and reportedAt into existing devices',
    () async {
      final repository = _FakeDeviceRepository(
        devices: _initialDevices(),
        states: const [
          DeviceStateApiModel(
            deviceId: 'light-01',
            power: DevicePower.off,
            reportedAt: '08:00 05/17/2026',
          ),
          DeviceStateApiModel(
            deviceId: 'light-02',
            power: DevicePower.on,
            reportedAt: '08:00 05/17/2026',
          ),
        ],
      );
      final viewModel = DeviceDashboardViewModel(
        repository: repository,
        pollInterval: null,
      );

      await viewModel.load();
      await viewModel.refreshDeviceStates();

      final light1 = viewModel.deviceById('light-01')!;
      final light2 = viewModel.deviceById('light-02')!;
      expect(light1.power, DevicePower.off);
      expect(light1.reportedAt, '08:00 05/17/2026');
      expect(light2.power, DevicePower.on);
      expect(light2.reportedAt, '08:00 05/17/2026');
      // Refresh should not re-fetch the whole device list.
      expect(repository.fetchDevicesCallCount, 1);
      expect(repository.refreshDeviceStatesCallIds, [
        ['light-01', 'light-02'],
      ]);
    },
  );

  test(
    'refreshDeviceStates marks the device unreachable when state reports it',
    () async {
      final repository = _FakeDeviceRepository(
        devices: _initialDevices(),
        states: const [
          DeviceStateApiModel(
            deviceId: 'light-01',
            power: DevicePower.unreachable,
            reportedAt: '08:00 05/17/2026',
          ),
        ],
      );
      final viewModel = DeviceDashboardViewModel(
        repository: repository,
        pollInterval: null,
      );

      await viewModel.load();
      await viewModel.refreshDeviceStates();

      final light1 = viewModel.deviceById('light-01')!;
      expect(light1.power, DevicePower.unreachable);
      expect(light1.isOnline, isFalse);
      expect(light1.isReachable, isFalse);
    },
  );

  test(
    'refreshDeviceStates surfaces a friendly error without leaking raw exception text',
    () async {
      final repository = _FakeDeviceRepository(
        devices: _initialDevices(),
        refreshError: const ApiException(
          statusCode: 500,
          kind: ApiErrorKind.server,
          message: 'boom',
        ),
      );
      final viewModel = DeviceDashboardViewModel(
        repository: repository,
        pollInterval: null,
      );

      await viewModel.load();
      await viewModel.refreshDeviceStates();

      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.errorMessage, contains('Khong cap nhat duoc'));
      expect(viewModel.errorMessage, isNot(contains('boom')));
      // Devices are kept even when refresh fails.
      expect(viewModel.devices, hasLength(2));
      expect(viewModel.deviceById('light-01')!.power, DevicePower.on);
    },
  );

  test('dispose cancels the polling timer so no leaked refresh fires', () async {
    final repository = _FakeDeviceRepository(
      devices: _initialDevices(),
      states: const [
        DeviceStateApiModel(deviceId: 'light-01', power: DevicePower.off),
      ],
    );
    final viewModel = DeviceDashboardViewModel(
      repository: repository,
      pollInterval: const Duration(milliseconds: 20),
    );

    await viewModel.load();
    final refreshCountBeforeDispose = repository.refreshDeviceStatesCallIds.length;

    viewModel.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(
      repository.refreshDeviceStatesCallIds.length,
      refreshCountBeforeDispose,
      reason: 'no refresh tick should fire after dispose',
    );
  });
}

List<SmartDevice> _initialDevices() {
  return const [
    SmartDevice(
      id: 'light-01',
      deviceType: 'light',
      name: 'Lab Light 01',
      isOnline: true,
      power: DevicePower.on,
      reportedAt: '07:00 05/17/2026',
    ),
    SmartDevice(
      id: 'light-02',
      deviceType: 'light',
      name: 'Hallway Light',
      isOnline: true,
      power: DevicePower.off,
      reportedAt: '07:00 05/17/2026',
    ),
  ];
}

class _FakeDeviceRepository implements DeviceRepository {
  _FakeDeviceRepository({
    required List<SmartDevice> devices,
    List<DeviceStateApiModel> states = const [],
    Object? refreshError,
  }) : _devices = List.of(devices),
       _states = List.of(states),
       _refreshError = refreshError;

  final List<SmartDevice> _devices;
  final List<DeviceStateApiModel> _states;
  final Object? _refreshError;

  int fetchDevicesCallCount = 0;
  final List<List<String>> refreshDeviceStatesCallIds = [];

  @override
  Future<CloudStatus> fetchCloudStatus() async => const CloudStatus.mock();

  @override
  Future<List<SmartDevice>> fetchDevices() async {
    fetchDevicesCallCount += 1;
    return List.unmodifiable(_devices);
  }

  @override
  Future<List<EventLog>> fetchEvents({String? deviceId}) async => const [];

  @override
  Future<CommandResult> sendLightPowerCommand({
    required String deviceId,
    required DevicePower target,
  }) async => throw UnimplementedError();

  @override
  Future<CommandResult> fetchCommand(String commandId) async =>
      throw UnimplementedError();

  @override
  Future<List<DeviceStateApiModel>> refreshDeviceStates(
    List<String> deviceIds,
  ) async {
    refreshDeviceStatesCallIds.add(List.of(deviceIds));
    if (_refreshError != null) {
      throw _refreshError;
    }
    return List.unmodifiable(_states);
  }
}
