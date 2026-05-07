import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/main.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/home/widgets/gateway_status_card.dart';

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required bool useMockApi,
  }) async {
    await tester.pumpWidget(
      ZigbeeSmartBuildingApp(
        repository: MockDeviceRepository(),
        apiBaseUrl: useMockApi ? 'mock' : 'http://98.83.4.87:8000',
        useMockApi: useMockApi,
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('renders LIGHT control dashboard', (tester) async {
    await pumpDashboard(tester, useMockApi: true);

    expect(find.text('Home'), findsWidgets);
    expect(find.text('QUICK LIGHTS'), findsOneWidget);
    expect(find.text('Lab Light 01'), findsOneWidget);
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
}
