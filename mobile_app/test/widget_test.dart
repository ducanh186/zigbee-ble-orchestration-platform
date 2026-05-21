import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zigbee_smart_building/data/repositories/mock_automation_repository.dart';
import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/domain/models/event_log.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/domain/repositories/device_repository.dart';
import 'package:zigbee_smart_building/main.dart';
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

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required bool useMockApi,
    DeviceRepository? repository,
  }) async {
    // SCRUM-29 wraps the app in an auth gate. Pre-authenticate the dashboard
    // tests so they continue to render the shell on first frame.
    final authViewModel = AuthViewModel(repository: _PreAuthedRepository());
    await authViewModel.login(username: 'operator', password: 'password');

    await tester.pumpWidget(
      ZigbeeSmartBuildingApp(
        repository: repository ?? MockDeviceRepository(),
        automationRepository: MockAutomationRepository(),
        apiBaseUrl: useMockApi ? 'mock' : 'http://98.83.4.87:8000',
        useMockApi: useMockApi,
        authViewModelOverride: authViewModel,
      ),
    );

    await tester.pumpAndSettle();
  }

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
    expect(find.text('Switch toggles one light'), findsOneWidget);
    expect(find.text('Save rule'), findsOneWidget);
    // Template "Motion becomes occupied" now also appears in the grid,
    // alongside the rule card behind the scrim.
    expect(find.text('Motion becomes occupied'), findsWidgets);

    // Dismiss via Cancel to confirm Cancel works.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Save rule'), findsNothing);

    await tester.tap(find.text('Provisioning'));
    await tester.pumpAndSettle();

    expect(find.text('Provisioning'), findsWidgets);
    expect(find.text('Provisioning placeholder'), findsOneWidget);
  });

  testWidgets('settings owns devices logs account logout and runtime toggle', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.textContaining('Run remote mode'), findsNothing);

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
    expect(find.text('Poll interval'), findsOneWidget);
    expect(find.text('Command timeout'), findsOneWidget);

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(find.text('Device inventory'), findsOneWidget);
    expect(find.text('Cloud logs'), findsOneWidget);

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

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

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();

    expect(find.text('Cài đặt'), findsWidgets);
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('Ngôn ngữ'), findsOneWidget);

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

    expect(find.text('Nhật ký cloud'), findsOneWidget);
  });

  testWidgets('settings profile and logs sections collapse and expand', (
    tester,
  ) async {
    await pumpDashboard(tester, useMockApi: true);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Grey'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-theme-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Grey'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-theme-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Grey'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-appearance-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-appearance-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);

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

  test('grey theme uses the cream / be sữa palette from the design system', () {
    // Tokens mirror /colors_and_type.css [data-theme="grey"] in the design
    // system. The enum value is still called `grey` but visually it's
    // warm milk-beige (log-friendly), not slate.
    expect(AppPalette.grey.background, const Color(0xFFF0EBE0));
    expect(AppPalette.grey.surface, const Color(0xFFF8F4EB));
    expect(AppPalette.grey.primary, const Color(0xFF6B5F4E));
    expect(AppPalette.grey.textPrimary, const Color(0xFF1F1A12));
    expect(AppPalette.grey.textSecondary, const Color(0xFF756B5D));
    expect(AppPalette.grey.border, const Color(0xFFDDD6C7));
  });
}
