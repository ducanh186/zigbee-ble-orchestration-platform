import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zigbee_smart_building/data/repositories/mock_automation_repository.dart';
import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
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

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required bool useMockApi,
  }) async {
    // SCRUM-29 wraps the app in an auth gate. Pre-authenticate the dashboard
    // tests so they continue to render the shell on first frame.
    final authViewModel = AuthViewModel(repository: _PreAuthedRepository());
    await authViewModel.login(username: 'operator', password: 'password');

    await tester.pumpWidget(
      ZigbeeSmartBuildingApp(
        repository: MockDeviceRepository(),
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
