import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/domain/models/command_result.dart';
import 'package:zigbee_smart_building/domain/models/command_status.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/domain/models/device_power.dart';
import 'package:zigbee_smart_building/domain/models/event_log.dart';
import 'package:zigbee_smart_building/domain/models/smart_device.dart';
import 'package:zigbee_smart_building/domain/repositories/device_repository.dart';
import 'package:zigbee_smart_building/main.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/home/widgets/gateway_status_card.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    required DeviceRepository repository,
    required bool useMockApi,
  }) async {
    await tester.pumpWidget(
      ZigbeeSmartBuildingApp(
        repository: repository,
        apiBaseUrl: useMockApi ? 'mock' : 'http://98.83.4.87:8000',
        useMockApi: useMockApi,
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required bool useMockApi,
  }) async {
    await pumpApp(
      tester,
      repository: MockDeviceRepository(),
      useMockApi: useMockApi,
    );
  }

  testWidgets('renders LIGHT control dashboard with devices tab', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Automation'), findsOneWidget);
    expect(find.text('Provisioning'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Logs'), findsNothing);
    expect(find.text('QUICK LIGHTS'), findsOneWidget);
    expect(find.text('Lab Light 01'), findsOneWidget);
  });

  testWidgets('devices tab lists devices and shows inline light controls', (
    tester,
  ) async {
    final repository = _TestDeviceRepository(
      devices: const [
        SmartDevice(
          id: 'light-01',
          deviceType: 'light',
          name: 'Lab Light 01',
          isOnline: true,
          power: DevicePower.off,
          roomId: 'lab01',
          reportedAt: '07:16 05/07/2026',
        ),
        SmartDevice(
          id: 'motion-01',
          deviceType: 'motion',
          name: 'Lab Motion',
          isOnline: true,
          power: DevicePower.unknown,
          roomId: 'lab01',
          reportedAt: '07:15 05/07/2026',
        ),
      ],
    );

    await pumpApp(tester, repository: repository, useMockApi: true);

    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();

    expect(find.text('Lab Light 01'), findsOneWidget);
    expect(find.text('Lab Motion'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ON'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'OFF'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
  });

  testWidgets('devices tab ON and OFF buttons send command and refresh state', (
    tester,
  ) async {
    final repository = _TestDeviceRepository(
      devices: const [
        SmartDevice(
          id: 'light-01',
          deviceType: 'light',
          name: 'Lab Light 01',
          isOnline: true,
          power: DevicePower.off,
          roomId: 'lab01',
          reportedAt: '07:16 05/07/2026',
        ),
      ],
    );

    await pumpApp(tester, repository: repository, useMockApi: true);

    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'ON'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'OFF'), findsOneWidget);
    expect(repository.currentPower('light-01'), DevicePower.off);

    await tester.tap(find.widgetWithText(FilledButton, 'ON'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(repository.sentTargets, [DevicePower.on]);
    expect(repository.currentPower('light-01'), DevicePower.on);
    expect(find.widgetWithText(FilledButton, 'ON'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'OFF'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'OFF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(repository.sentTargets, [DevicePower.on, DevicePower.off]);
    expect(repository.currentPower('light-01'), DevicePower.off);
    expect(find.widgetWithText(FilledButton, 'ON'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'OFF'), findsOneWidget);
  });

  testWidgets('automation and provisioning tabs show placeholders', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.text('Automation'));
    await tester.pumpAndSettle();

    expect(find.text('Automation Rules'), findsWidgets);
    expect(find.text('Rule setup placeholder'), findsOneWidget);

    await tester.tap(find.text('Provisioning'));
    await tester.pumpAndSettle();

    expect(find.text('Provisioning'), findsWidgets);
    expect(find.text('Provisioning placeholder'), findsOneWidget);
  });

  testWidgets('settings owns devices logs account logout and runtime toggle', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Device inventory'), findsOneWidget);
    expect(find.text('Cloud logs'), findsOneWidget);
    expect(find.text('Runtime'), findsOneWidget);
    expect(find.textContaining('Run remote mode'), findsNothing);
    expect(find.text('API_BASE_URL'), findsNothing);

    await tester.tap(find.text('Runtime'));
    await tester.pumpAndSettle();

    expect(find.text('API_BASE_URL'), findsOneWidget);

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Logout'), findsOneWidget);

    await tester.ensureVisible(find.text('Device inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Device inventory'));
    await tester.pumpAndSettle();

    expect(find.text('Devices'), findsWidgets);
    expect(find.text('Lab Light 01'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cloud logs'));
    await tester.pumpAndSettle();

    expect(find.text('Logs'), findsWidgets);
    expect(find.text('LIGHT light-01'), findsOneWidget);
  });

  testWidgets('does not present mock data as a real gateway status', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    expect(find.text('Mock gateway log'), findsOneWidget);
    expect(find.text('Gateway online'), findsNothing);
  });

  testWidgets('home dashboard does not overflow on a narrow phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDashboard(tester, useMockApi: true);

    expect(tester.takeException(), isNull);
  });

  testWidgets('gateway status card shows unknown instead of guessing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme(AppThemeMode.light),
        home: const Scaffold(
          body: GatewayStatusCard(
            status: CloudStatus.unknown(
              detail: 'No gateway status log found in cloud events',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gateway status unknown'), findsOneWidget);
    expect(
      find.text('No gateway status log found in cloud events'),
      findsOneWidget,
    );
  });

  test('grey theme uses a neutral blue grey palette', () {
    expect(AppPalette.grey.background, const Color(0xFFF1F5F9));
    expect(AppPalette.grey.primary, const Color(0xFF475569));
    expect(AppPalette.grey.textSecondary, const Color(0xFF64748B));
  });
}

class _TestDeviceRepository implements DeviceRepository {
  _TestDeviceRepository({required List<SmartDevice> devices})
    : _devices = List<SmartDevice>.from(devices);

  final List<SmartDevice> _devices;
  final List<DevicePower> sentTargets = [];
  int _nextCommand = 1;
  String? _lastDeviceId;
  DevicePower? _lastTarget;

  @override
  Future<CloudStatus> fetchCloudStatus() async => const CloudStatus.mock();

  @override
  Future<List<SmartDevice>> fetchDevices() async =>
      List<SmartDevice>.unmodifiable(_devices);

  DevicePower? currentPower(String deviceId) {
    for (final device in _devices) {
      if (device.id == deviceId) {
        return device.power;
      }
    }
    return null;
  }

  @override
  Future<List<EventLog>> fetchEvents({String? deviceId}) async => const [];

  @override
  Future<CommandResult> sendLightPowerCommand({
    required String deviceId,
    required DevicePower target,
  }) async {
    _lastDeviceId = deviceId;
    _lastTarget = target;
    sentTargets.add(target);
    return CommandResult(
      id: 'cmd-${_nextCommand++}',
      deviceId: deviceId,
      status: CommandStatus.accepted,
    );
  }

  @override
  Future<CommandResult> fetchCommand(String commandId) async {
    final lastDeviceId = _lastDeviceId;
    final lastTarget = _lastTarget;

    if (lastDeviceId != null && lastTarget != null) {
      final index = _devices.indexWhere((device) => device.id == lastDeviceId);
      if (index != -1) {
        _devices[index] = _devices[index].copyWith(
          power: lastTarget,
          isOnline: true,
          reportedAt: 'now',
        );
      }
    }

    return CommandResult(
      id: commandId,
      deviceId: lastDeviceId ?? '',
      status: CommandStatus.executed,
    );
  }
}
