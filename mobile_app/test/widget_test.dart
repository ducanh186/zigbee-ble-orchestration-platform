import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zigbee_smart_building/data/repositories/mock_automation_repository.dart';
import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/domain/models/automation_rule.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/domain/models/device_power.dart';
import 'package:zigbee_smart_building/domain/models/event_log.dart';
import 'package:zigbee_smart_building/domain/models/smart_device.dart';
import 'package:zigbee_smart_building/domain/repositories/automation_repository.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/domain/repositories/device_repository.dart';
import 'package:zigbee_smart_building/l10n/app_localizations.dart';
import 'package:zigbee_smart_building/main.dart';
import 'package:zigbee_smart_building/ui/core/localization/locale_controller.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/auth/view_models/auth_view_model.dart';
import 'package:zigbee_smart_building/ui/features/devices/view_models/device_dashboard_view_model.dart';
import 'package:zigbee_smart_building/ui/features/home/widgets/gateway_status_card.dart';

class _PreAuthedRepository implements AuthRepository {
  _PreAuthedRepository({this.role = 'parent'});

  final String role;

  @override
  Future<AuthSession?> restoreSession() async => AuthSession(
    accessToken: 'test-token',
    username: role,
    userId: '$role-1',
    role: role,
    homeId: 'home-01',
    expiresAt: DateTime.utc(2026, 6, 1, 12),
  );

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async => AuthSession(
    accessToken: 'test-token',
    username: username,
    userId: '$role-1',
    role: role,
    homeId: 'home-01',
    expiresAt: DateTime.utc(2026, 6, 1, 12),
  );

  @override
  Future<AuthSession?> refreshSession({required String refreshToken}) async =>
      null;

  @override
  Future<void> logout() async {}

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}
}

class _GatewayHealthRepository extends MockDeviceRepository {
  @override
  Future<List<EventLog>> fetchEvents({String? deviceId}) async {
    return const [
      EventLog(
        id: 'gateway-1',
        eventType: 'gateway_health',
        message: '{uptime_ms: 1444096, network_status: connected}',
        occurredAt: '11:53 05/17/2026',
        source: 'cloud/gateway',
      ),
    ];
  }
}

class _DeviceEventsRepository extends MockDeviceRepository {
  final List<String?> requestedDeviceIds = [];

  @override
  Future<List<EventLog>> fetchEvents({String? deviceId}) async {
    requestedDeviceIds.add(deviceId);
    if (deviceId == 'pir-01') {
      return const [
        EventLog(
          id: 'motion-event-1',
          deviceId: 'pir-01',
          eventType: 'occupancy_changed',
          message: 'occupied',
          occurredAt: '07:20 05/21/2026',
          source: 'gateway',
        ),
      ];
    }
    if (deviceId == 'light-01') {
      return const [
        EventLog(
          id: 'light-registry-1',
          deviceId: 'light-01',
          eventType: 'device_registry',
          message:
              '{eui64: 000000000000004F, clusters: [0x0006, 0x0008], metadata_source: gateway_mvp_inferred}',
          occurredAt: '07:18 05/21/2026',
          source: 'gateway',
        ),
      ];
    }
    return super.fetchEvents(deviceId: deviceId);
  }
}

class _ImmediateRenameRepository extends MockDeviceRepository {
  String? renamedDeviceId;
  String? renamedName;
  String _lightName = 'Lab Light 01';

  @override
  Future<List<SmartDevice>> fetchDevices() async {
    final devices = await super.fetchDevices();
    return [
      for (final device in devices)
        device.id == 'light-01' ? device.copyWith(name: _lightName) : device,
    ];
  }

  @override
  Future<SmartDevice> renameDeviceName({
    required String deviceId,
    required String name,
  }) async {
    renamedDeviceId = deviceId;
    renamedName = name;
    _lightName = name;
    return SmartDevice(
      id: deviceId,
      deviceType: 'light',
      name: name,
      eui64: '00124b0001aa22bb',
      roomId: 'lab01',
      isOnline: true,
      power: DevicePower.on,
    );
  }
}

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required bool useMockApi,
    DeviceRepository? repository,
    AutomationRepository? automationRepository,
    String role = 'parent',
  }) async {
    SharedPreferences.setMockInitialValues({});
    // SCRUM-29 wraps the app in an auth gate. Pre-authenticate the dashboard
    // tests so they continue to render the shell on first frame.
    final authViewModel = AuthViewModel(
      repository: _PreAuthedRepository(role: role),
    );
    await authViewModel.login(username: role, password: 'password');

    await tester.pumpWidget(
      ZigbeeSmartBuildingApp(
        repository: repository ?? MockDeviceRepository(),
        automationRepository:
            automationRepository ?? MockAutomationRepository(),
        apiBaseUrl: useMockApi ? 'mock' : 'http://98.83.4.87:8000',
        useMockApi: useMockApi,
        authViewModelOverride: authViewModel,
      ),
    );

    await tester.pumpAndSettle();
  }

  test('theme and language controllers restore saved preferences', () async {
    SharedPreferences.setMockInitialValues({
      'app_theme_mode': 'grey',
      'locale_language_code': 'vi',
    });

    final themeController = ThemeController();
    final localeController = LocaleController();
    await Future<void>.delayed(Duration.zero);

    expect(themeController.mode, AppThemeMode.grey);
    expect(localeController.locale.languageCode, 'vi');

    themeController.setMode(AppThemeMode.light);
    localeController.setLocaleCode('en');
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('app_theme_mode'), 'light');
    expect(prefs.getString('locale_language_code'), 'en');
  });

  testWidgets('renders LIGHT control dashboard', (tester) async {
    await pumpDashboard(tester, useMockApi: true);

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Automation'), findsOneWidget);
    expect(find.text('Provisioning'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Devices'), findsNothing);
    expect(find.text('Logs'), findsNothing);
    expect(find.text('QUICK LIGHTS'), findsOneWidget);
    expect(find.text('Lab Light 01'), findsOneWidget);
  });

  testWidgets('environment readings are visible to parent viewer and member', (
    tester,
  ) async {
    for (final role in ['parent', 'viewer', 'member']) {
      await pumpDashboard(tester, useMockApi: true, role: role);

      await tester.scrollUntilVisible(
        find.text('ENVIRONMENT'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('28.5°C'), findsOneWidget, reason: 'role=$role');
      expect(find.text('48%'), findsOneWidget, reason: 'role=$role');
    }
  });

  testWidgets('automation tab shows rule list and opens create sheet', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.text('Automation'));
    await tester.pumpAndSettle();

    // List screen: title, dashed CTA, mock rule + section header. The mock
    // rule's template label ("Sensor becomes occupied") shows as the card
    // subtitle.
    expect(find.text('Automation Rules'), findsWidgets);
    expect(find.text('New rule'), findsWidgets);
    expect(find.text('Motion turns on lab lights'), findsOneWidget);
    expect(find.text('RULES'), findsOneWidget);
    expect(find.text('Sensor becomes occupied'), findsOneWidget);
    // Save button only exists inside the sheet.
    expect(find.text('Save rule'), findsNothing);

    // Open the bottom sheet and verify the create form.
    await tester.tap(find.text('New rule').last);
    await tester.pumpAndSettle();

    expect(find.text('CREATE RULE'), findsOneWidget);
    expect(find.text('RULE TYPE'), findsOneWidget);
    expect(find.byKey(const ValueKey('rule-kind-schedule')), findsOneWidget);
    expect(find.text('Save rule'), findsOneWidget);

    // Switching to the schedule rule type reveals the period chips.
    await tester.tap(find.byKey(const ValueKey('rule-kind-schedule')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('schedule-mode-daily')), findsOneWidget);

    // Dismiss via Cancel to confirm Cancel works.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Save rule'), findsNothing);

    await tester.tap(find.text('Provisioning'));
    await tester.pumpAndSettle();

    expect(find.text('Provisioning'), findsWidgets);
    expect(find.text('PROVISIONING WIZARD'), findsOneWidget);
    expect(find.text('Device identity required'), findsOneWidget);
  });

  testWidgets('automation create sheet saves a manual rule without template', (
    tester,
  ) async {
    final automationRepository = _WidgetAutomationRepository();
    await pumpDashboard(
      tester,
      useMockApi: true,
      automationRepository: automationRepository,
    );

    await tester.tap(find.text('Automation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New rule').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Manual motion rule');
    await tester.ensureVisible(find.text('Lab Motion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab Motion'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Occupied'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Occupied'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lab Light 01').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab Light 01').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Turn on').last);
    await tester.pumpAndSettle();
    expect(find.text('Turn on'), findsWidgets);
    expect(find.text('Turn off'), findsOneWidget);
    expect(find.text('Toggle'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hallway Light').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hallway Light').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Turn on').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save rule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save rule'));
    await tester.pumpAndSettle();

    expect(automationRepository.createdDrafts, hasLength(1));
    final draft = automationRepository.createdDrafts.single;
    expect(draft.template, isNull);
    expect(draft.triggerDeviceId, 'pir-01');
    expect(draft.triggerDeviceType, AutomationDeviceType.motion);
    expect(draft.triggerState, {'occupancy': 'occupied'});
    expect(draft.targetLightIds, ['light-01', 'light-02']);
    expect(draft.targetActionCommands, {
      'light-01': AutomationActionCommand.off,
      'light-02': AutomationActionCommand.on,
    });
    expect(draft.actions.map((action) => action.command), [
      AutomationActionCommand.off,
      AutomationActionCommand.on,
    ]);
  });

  testWidgets('automation create sheet saves a temperature threshold rule', (
    tester,
  ) async {
    final automationRepository = _WidgetAutomationRepository();
    await pumpDashboard(
      tester,
      useMockApi: true,
      automationRepository: automationRepository,
    );

    await tester.tap(find.text('Automation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New rule').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('rule-name-field')),
      'High temperature turns on lab light',
    );
    await tester.ensureVisible(find.text('DHT11 Sensor'));
    await tester.tap(find.text('DHT11 Sensor'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('environment-metric-dropdown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('environment-operator-dropdown')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('environment-threshold-field')),
      '30',
    );

    await tester.ensureVisible(find.text('Lab Light 01').last);
    await tester.tap(find.text('Lab Light 01').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save rule'));
    await tester.tap(find.text('Save rule'));
    await tester.pumpAndSettle();

    expect(automationRepository.createdDrafts, hasLength(1));
    final draft = automationRepository.createdDrafts.single;
    expect(
      draft.trigger,
      isA<SensorThresholdAutomationTrigger>()
          .having(
            (trigger) => trigger.metric,
            'metric',
            EnvironmentMetric.temperature,
          )
          .having(
            (trigger) => trigger.operator,
            'operator',
            ThresholdOperator.gte,
          )
          .having((trigger) => trigger.threshold, 'threshold', 30),
    );
    expect(draft.actions.single.deviceId, 'light-01');
    expect(draft.actions.single.command, AutomationActionCommand.on);
  });

  testWidgets('automation rule delete button opens confirmation dialog', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.text('Automation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete rule').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete rule?'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('device inventory opens motion detail and loads device events', (
    tester,
  ) async {
    final repository = _DeviceEventsRepository();
    await pumpDashboard(tester, useMockApi: true, repository: repository);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Devices'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Lab Motion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab Motion'));
    await tester.pumpAndSettle();

    expect(find.text('Device detail'), findsOneWidget);
    expect(find.text('Lab Motion'), findsOneWidget);
    expect(find.text('Occupied'), findsWidgets);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('OCCUPANCY TIMELINE'), findsOneWidget);
    expect(find.text('Latest occupancy'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('RECENT EVENTS'), findsOneWidget);
    expect(find.text('occupancy_changed'), findsOneWidget);
    expect(repository.requestedDeviceIds, contains('pir-01'));
  });

  testWidgets('shell does not show sticky notification popup', (tester) async {
    await pumpDashboard(tester, useMockApi: true);

    expect(find.byTooltip('Notifications'), findsNothing);
    expect(find.text('Notification Center'), findsNothing);
  });

  testWidgets('device detail keeps verbose cloud event payloads compact', (
    tester,
  ) async {
    final repository = _DeviceEventsRepository();
    await pumpDashboard(tester, useMockApi: true, repository: repository);

    await tester.scrollUntilVisible(
      find.text('Lab Light 01'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab Light 01'));
    await tester.pumpAndSettle();

    expect(find.text('Device detail'), findsOneWidget);
    expect(find.text('Device registry updated'), findsOneWidget);
    expect(find.textContaining('metadata_source'), findsNothing);
    expect(repository.requestedDeviceIds, contains('light-01'));
  });

  testWidgets('device detail renames display label only', (tester) async {
    final repository = _ImmediateRenameRepository();
    await pumpDashboard(tester, useMockApi: true, repository: repository);

    await tester.scrollUntilVisible(
      find.text('Lab Light 01'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab Light 01'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rename device'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Desk lamp');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.renamedDeviceId, 'light-01');
    expect(repository.renamedName, 'Desk lamp');
    final viewModel = Provider.of<DeviceDashboardViewModel>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    expect(viewModel.deviceById('light-01')?.name, 'Desk lamp');
    expect(find.text('Desk lamp', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('light-01'), findsOneWidget);
  });

  testWidgets('settings shows compact parent-facing sections', (tester) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Account Center'), findsNothing);
    expect(find.text('HOME SUMMARY'), findsOneWidget);
    expect(find.text('Parent · Home Owner'), findsOneWidget);
    expect(find.text('Home: home-01'), findsOneWidget);
    expect(find.text('Role permissions'), findsNothing);
    expect(find.text('Member'), findsNothing);
    expect(find.text('System Admin'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('HOME MANAGEMENT'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('HOME MANAGEMENT'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Add new device'), findsOneWidget);
    expect(find.text('Automation rules'), findsOneWidget);
    expect(find.text('Activity history'), findsOneWidget);
    expect(find.text('Device control'), findsNothing);
    expect(find.text('Automation CRUD'), findsNothing);
    expect(find.text('Provisioning device'), findsNothing);
    expect(find.text('Delete device'), findsNothing);
    expect(find.text('Rediscover device'), findsNothing);
    expect(find.text('SYSTEM ONLY'), findsNothing);
    expect(find.text('Production config'), findsNothing);
    expect(find.text('MQTT/TLS security'), findsNothing);
    expect(find.text('API base URL'), findsNothing);
    expect(find.text('HTTPS status'), findsNothing);
    expect(find.text('Poll interval'), findsNothing);
    expect(find.text('Command timeout'), findsNothing);
    expect(find.text('Build'), findsNothing);
    expect(find.text('Diagnostics'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Theme'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byType(SegmentedButton<AppThemeMode>), findsNothing);
    expect(find.byType(SegmentedButton<String>), findsNothing);

    await tester.scrollUntilVisible(
      find.text('ADVANCED'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Connection settings'), findsOneWidget);
    expect(find.text('API base URL'), findsNothing);
    expect(find.text('HTTPS status'), findsNothing);
    await tester.tap(find.text('Connection settings'));
    await tester.pumpAndSettle();
    expect(find.text('API base URL'), findsOneWidget);
    expect(find.text('HTTPS status'), findsOneWidget);
    expect(find.text('Poll interval'), findsOneWidget);
    expect(find.text('Command timeout'), findsOneWidget);

    expect(find.textContaining('operator'), findsNothing);
    expect(find.textContaining('Operator'), findsNothing);
    expect(find.text('Gateway ID'), findsNothing);
    expect(find.text('API Gateway'), findsNothing);
    expect(find.byKey(const Key('settings-appearance-toggle')), findsNothing);
    expect(find.byKey(const Key('settings-cloud-toggle')), findsNothing);
    expect(find.byKey(const Key('settings-workspace-toggle')), findsNothing);
    expect(find.byKey(const Key('settings-about-toggle')), findsNothing);
    expect(find.textContaining('Run remote mode'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Devices'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();

    expect(find.text('Devices'), findsWidgets);
    expect(find.text('Search devices'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Sensors'), findsOneWidget);
    expect(find.text('Lab Light 01'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hallway');
    await tester.pumpAndSettle();

    expect(find.text('Hallway Light'), findsOneWidget);
    expect(find.text('Lab Light 01'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Activity history'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity history'));
    await tester.pumpAndSettle();

    expect(find.text('Logs'), findsWidgets);
    expect(
      find.text('Success - light-01 - State reported - on'),
      findsOneWidget,
    );
    expect(
      find.text('Success - light-02 - Command executed - off'),
      findsOneWidget,
    );
    expect(find.text('Event payload'), findsNothing);
  });

  testWidgets('settings logout requires confirmation', (tester) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Logout'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('settings language switch updates localized copy', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Language'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, 1600),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cài đặt'), findsWidgets);
    expect(find.byKey(const Key('settings-appearance-toggle')), findsNothing);
    expect(find.text('Tóm tắt home'), findsOneWidget);
    expect(find.text('Chủ nhà'), findsWidgets);
    expect(find.text('Home: home-01'), findsOneWidget);
    expect(find.textContaining('operator'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Ngôn ngữ'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ngôn ngữ'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Lịch sử hoạt động'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử hoạt động'), findsOneWidget);
  });

  testWidgets('viewer shell hides mutation entry points', (tester) async {
    await pumpDashboard(tester, useMockApi: true, role: 'viewer');

    expect(find.text('Provisioning'), findsNothing);

    await tester.tap(find.text('Automation'));
    await tester.pumpAndSettle();

    expect(find.text('Automation Rules'), findsWidgets);
    expect(find.text('New rule'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('settings compact rows stay stable during navigation', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Parent · Home Owner'), findsOneWidget);
    expect(find.text('Home: home-01'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Theme'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.byKey(const Key('settings-theme-toggle')), findsNothing);
    expect(find.byKey(const Key('settings-language-toggle')), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Activity history'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity history'));
    await tester.pumpAndSettle();

    expect(find.text('State reported: on'), findsNothing);

    await tester.tap(find.byKey(const Key('log-toggle-1')));
    await tester.pumpAndSettle();

    expect(find.text('State reported: on'), findsOneWidget);
  });

  testWidgets('home hub health logs use a compact consistent summary', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      useMockApi: true,
      repository: _GatewayHealthRepository(),
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Activity history'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity history'));
    await tester.pumpAndSettle();

    expect(
      find.text('Success - home hub - Health reported - connected, 1444096ms'),
      findsOneWidget,
    );
    expect(
      find.text('{uptime_ms: 1444096, network_status: connected}'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('log-toggle-gateway-1')));
    await tester.pumpAndSettle();

    expect(
      find.text('{uptime_ms: 1444096, network_status: connected}'),
      findsOneWidget,
    );
  });

  testWidgets('home Devices metric opens device inventory', (tester) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.text('DEVICES'));
    await tester.pumpAndSettle();

    expect(find.text('Devices'), findsWidgets);
    expect(find.text('Search devices'), findsOneWidget);
    expect(find.text('Lab Light 01'), findsOneWidget);
  });

  test('theme defaults to dark mode', () {
    expect(ThemeController().mode, AppThemeMode.dark);
  });

  testWidgets('does not present mock data as a real home hub status', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    expect(find.text('Mock home hub log'), findsOneWidget);
    expect(find.text('Home hub online'), findsNothing);
  });

  testWidgets('home dashboard does not overflow on a narrow phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDashboard(tester, useMockApi: true);

    expect(tester.takeException(), isNull);
  });

  testWidgets('home hub status card shows unknown instead of guessing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.theme(AppThemeMode.light),
        home: const Scaffold(
          body: GatewayStatusCard(
            status: CloudStatus.unknown(
              detail: 'No home hub status log found in cloud events',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home hub status unknown'), findsOneWidget);
    expect(
      find.text('No home hub status log found in cloud events'),
      findsOneWidget,
    );
  });

  test(
    'grey theme uses the cream / be sá»¯a palette from the design system',
    () {
      // Tokens mirror /colors_and_type.css [data-theme="grey"] in the design
      // system. The enum value is still called `grey` but visually it's
      // warm milk-beige (log-friendly), not slate.
      expect(AppPalette.grey.background, const Color(0xFFF0EBE0));
      expect(AppPalette.grey.surface, const Color(0xFFF8F4EB));
      expect(AppPalette.grey.primary, const Color(0xFF6B5F4E));
      expect(AppPalette.grey.textPrimary, const Color(0xFF1F1A12));
      expect(AppPalette.grey.textSecondary, const Color(0xFF756B5D));
      expect(AppPalette.grey.border, const Color(0xFFDDD6C7));
    },
  );
}

class _WidgetAutomationRepository implements AutomationRepository {
  final List<AutomationRule> _rules = [];
  final List<AutomationRuleDraft> createdDrafts = [];
  final List<String> deletedRuleIds = [];

  @override
  Future<List<AutomationRule>> fetchRules() async => List.unmodifiable(_rules);

  @override
  Future<AutomationRule> fetchRule(String ruleId) async {
    return _rules.firstWhere((rule) => rule.id == ruleId);
  }

  @override
  Future<AutomationRule> createRule(AutomationRuleDraft draft) async {
    createdDrafts.add(draft);
    final rule = AutomationRule(
      id: 'automation-widget-01',
      name: draft.name,
      enabled: draft.enabled,
      trigger: draft.trigger,
      actions: draft.actions,
      syncStatus: AutomationSyncStatus.synced,
      lastRunStatus: AutomationLastRunStatus.neverRun,
    );
    _rules.add(rule);
    return rule;
  }

  @override
  Future<AutomationRule> enableRule(String ruleId) async => fetchRule(ruleId);

  @override
  Future<AutomationRule> disableRule(String ruleId) async => fetchRule(ruleId);

  @override
  Future<void> deleteRule(String ruleId) async {
    deletedRuleIds.add(ruleId);
    _rules.removeWhere((rule) => rule.id == ruleId);
  }
}
