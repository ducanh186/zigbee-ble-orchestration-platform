import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zigbee_smart_building/domain/models/device_power.dart';
import 'package:zigbee_smart_building/domain/models/occupancy_state.dart';
import 'package:zigbee_smart_building/domain/models/smart_device.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/core/widgets/status_badge.dart';
import 'package:zigbee_smart_building/ui/features/devices/widgets/occupancy_status_card.dart';

Future<void> _pumpCard(
  WidgetTester tester,
  SmartDevice device, {
  DateTime? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme(AppThemeMode.light),
      home: Scaffold(
        body: OccupancyStatusCard(device: device, now: now),
      ),
    ),
  );
}

SmartDevice _motion({
  required OccupancyState? occupancy,
  String? reportedAt,
}) {
  return SmartDevice(
    id: 'pir-01',
    deviceType: 'motion',
    name: 'Lab Motion',
    roomId: 'lab01',
    isOnline: true,
    power: DevicePower.unknown,
    reportedAt: reportedAt,
    occupancy: occupancy,
  );
}

void main() {
  testWidgets('occupied state renders OCCUPIED badge and Vietnamese label',
      (tester) async {
    await _pumpCard(
      tester,
      _motion(
        occupancy: OccupancyState.occupied,
        reportedAt: '2026-05-17T07:55:00Z',
      ),
      now: DateTime.utc(2026, 5, 17, 8, 0),
    );

    expect(find.text('Lab Motion'), findsOneWidget);
    expect(find.text('lab01 - Co nguoi'), findsOneWidget);
    expect(find.text('5 phut truoc'), findsOneWidget);

    final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
    expect(badge.label, 'OCCUPIED');
    expect(badge.tone, BadgeTone.success);
  });

  testWidgets('clear state renders CLEAR badge and Vang label', (tester) async {
    await _pumpCard(
      tester,
      _motion(
        occupancy: OccupancyState.unoccupied,
        reportedAt: '2026-05-17T07:30:00Z',
      ),
      now: DateTime.utc(2026, 5, 17, 8, 0),
    );

    expect(find.text('lab01 - Vang'), findsOneWidget);
    expect(find.text('30 phut truoc'), findsOneWidget);

    final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
    expect(badge.label, 'CLEAR');
    expect(badge.tone, BadgeTone.neutral);
  });

  testWidgets('unknown / no data renders UNKNOWN badge and placeholder timestamp',
      (tester) async {
    await _pumpCard(tester, _motion(occupancy: null, reportedAt: null));

    expect(find.text('lab01 - Khong xac dinh'), findsOneWidget);
    expect(find.text('Chua co du lieu'), findsOneWidget);

    final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
    expect(badge.label, 'UNKNOWN');
    expect(badge.tone, BadgeTone.warning);
  });

  testWidgets('reportedAt within the last minute renders "Vua moi"',
      (tester) async {
    await _pumpCard(
      tester,
      _motion(
        occupancy: OccupancyState.occupied,
        reportedAt: '2026-05-17T07:59:30Z',
      ),
      now: DateTime.utc(2026, 5, 17, 8, 0),
    );

    expect(find.text('Vua moi'), findsOneWidget);
  });
}
