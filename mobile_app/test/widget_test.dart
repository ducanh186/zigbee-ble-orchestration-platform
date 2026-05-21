import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zigbee_smart_building/data/repositories/mock_automation_repository.dart';
import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/domain/models/automation_rule.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/domain/models/event_log.dart';
import 'package:zigbee_smart_building/domain/repositories/automation_repository.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/domain/repositories/device_repository.dart';
import 'package:zigbee_smart_building/main.dart';
import 'package:zigbee_smart_building/ui/core/localization/locale_controller.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/auth/view_models/auth_view_model.dart';
import 'package:zigbee_smart_building/ui/features/home/widgets/gateway_status_card.dart';

class _PreAuthedRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async => const AuthSession(accessToken: 'test-token');

  @override
  Future<void> logout() async {}
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

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required bool useMockApi,
    DeviceRepository? repository,
    AutomationRepository? automationRepository,
  }) async {
    SharedPreferences.setMockInitialValues({});
    // SCRUM-29 wraps the app in an auth gate. Pre-authenticate the dashboard
    // tests so they continue to render the shell on first frame.
    final authViewModel = AuthViewModel(repository: _PreAuthedRepository());
    await authViewModel.login(username: 'operator', password: 'password');

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

  testWidgets('automation tab shows rule list and opens create sheet', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.text('Automation'));
    await tester.pumpAndSettle();

    // List screen: title, dashed CTA, mock rule + section header. The mock
    // rule's template label ("Motion becomes occupied") shows as the card
    // subtitle.
    expect(find.text('Automation Rules'), findsWidgets);
    expect(find.text('New rule'), findsWidgets);
    expect(find.text('Motion turns on lab lights'), findsOneWidget);
    expect(find.text('RULES'), findsOneWidget);
    expect(find.text('Motion becomes occupied'), findsOneWidget);
    // Save button only exists inside the sheet.
    expect(find.text('Save rule'), findsNothing);

    // Open the bottom sheet and verify the create form.
    await tester.tap(find.text('New rule').last);
    await tester.pumpAndSettle();

    expect(find.text('CREATE RULE'), findsOneWidget);
    expect(find.text('QUICK TEMPLATE'), findsOneWidget);
    expect(find.text('Switch toggles one light'), findsNothing);
    expect(find.text('Save rule'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-template-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Switch toggles one light'), findsOneWidget);

    // Dismiss via Cancel to confirm Cancel works.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Save rule'), findsNothing);

    await tester.tap(find.text('Provisioning'));
    await tester.pumpAndSettle();

    expect(find.text('Provisioning'), findsWidgets);
    expect(find.text('Provisioning placeholder'), findsOneWidget);
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
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-workspace-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Device inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Device inventory'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Lab Motion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab Motion'));
    await tester.pumpAndSettle();

    expect(find.text('Device detail'), findsOneWidget);
    expect(find.text('Lab Motion'), findsOneWidget);
    expect(find.text('OCCUPIED'), findsWidgets);
    expect(
      find.text('OCCUPANCY TIMELINE', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Latest occupancy', skipOffstage: false), findsOneWidget);
    expect(find.text('RECENT EVENTS', skipOffstage: false), findsOneWidget);
    expect(find.text('occupancy_changed', skipOffstage: false), findsOneWidget);
    expect(repository.requestedDeviceIds, contains('pir-01'));
  });

  testWidgets('notification center categorizes and tracks unread events', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    expect(find.byTooltip('Notifications'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notification Center'), findsOneWidget);
    expect(find.text('Unread 4'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Automation'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Other'), findsOneWidget);

    await tester.tap(find.text('Mark read').first);
    await tester.pumpAndSettle();
    expect(find.text('Unread 3'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(find.text('Unread 0'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Automation'));
    await tester.pumpAndSettle();
    expect(find.text('occupancy_changed'), findsOneWidget);
    expect(find.text('LIGHT'), findsNothing);
  });

  testWidgets('device detail keeps verbose cloud event payloads compact', (
    tester,
  ) async {
    final repository = _DeviceEventsRepository();
    await pumpDashboard(tester, useMockApi: true, repository: repository);

    await tester.tap(
      find
          .ancestor(
            of: find.text('Lab Light 01'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Device detail'), findsOneWidget);
    expect(find.text('Device registry updated'), findsOneWidget);
    expect(find.textContaining('metadata_source'), findsNothing);
    expect(repository.requestedDeviceIds, contains('light-01'));
  });

  testWidgets('settings owns devices logs account logout and runtime toggle', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsNothing);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(find.textContaining('Run remote mode'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-operator-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Nguyen Tri'), findsOneWidget);
    expect(find.text('Field technician'), findsOneWidget);
    expect(find.text('ORGANIZATION'), findsOneWidget);
    expect(find.text('SIGNED IN SINCE'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();

    expect(find.text('CLOUD'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-cloud-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Poll interval'), findsOneWidget);
    expect(find.text('Command timeout'), findsOneWidget);

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-workspace-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Device inventory'), findsOneWidget);
    expect(find.text('Cloud logs'), findsOneWidget);

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('ABOUT'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-about-toggle')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Device inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Device inventory'));
    await tester.pumpAndSettle();

    expect(find.text('Devices'), findsWidgets);
    expect(find.text('Search devices'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Motion'), findsOneWidget);
    expect(find.text('Lab Light 01'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hallway');
    await tester.pumpAndSettle();

    expect(find.text('Hallway Light'), findsOneWidget);
    expect(find.text('Lab Light 01'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('settings-workspace-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-workspace-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cloud logs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cloud logs'));
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

  testWidgets('settings language switch updates localized copy', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-appearance-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-language-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vi'));
    await tester.pumpAndSettle();

    expect(find.text('Cài đặt'), findsWidgets);
    expect(find.text('Tài khoản'), findsNothing);
    expect(find.text('Ngôn ngữ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-operator-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ'), findsOneWidget);
    expect(find.text('Kỹ thuật hiện trường'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đổi mật khẩu'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('settings-workspace-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-workspace-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Nhật ký cloud'), findsOneWidget);
  });

  testWidgets('settings profile and logs sections collapse and expand', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsNothing);
    expect(find.text('Language'), findsNothing);
    expect(find.textContaining('Affects all'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-appearance-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Grey'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-theme-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Grey'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-theme-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Grey'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-appearance-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-appearance-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-operator-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(find.text('ORGANIZATION'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-session-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('ORGANIZATION'), findsNothing);

    await tester.tap(find.byKey(const Key('profile-session-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('ORGANIZATION'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('settings-workspace-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-workspace-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cloud logs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cloud logs'));
    await tester.pumpAndSettle();

    expect(find.text('State reported: on'), findsNothing);

    await tester.tap(find.byKey(const Key('log-toggle-1')));
    await tester.pumpAndSettle();

    expect(find.text('State reported: on'), findsOneWidget);
  });

  testWidgets('gateway health logs use a compact consistent summary', (
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
    await tester.tap(find.byKey(const Key('settings-workspace-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cloud logs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cloud logs'));
    await tester.pumpAndSettle();

    expect(
      find.text('Success - gateway - Health reported - connected, 1444096ms'),
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
