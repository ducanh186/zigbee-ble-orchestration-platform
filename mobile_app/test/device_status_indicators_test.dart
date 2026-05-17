import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zigbee_smart_building/domain/models/automation_rule.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/core/widgets/status_badge.dart';
import 'package:zigbee_smart_building/ui/features/automation/widgets/rule_status_row.dart';
import 'package:zigbee_smart_building/ui/features/home/widgets/gateway_status_card.dart';

/// SCRUM-50: device + cloud status indicators.
///
/// Verifies the four plan-mandated states (online, offline, syncing, unknown)
/// map to the correct [StatusBadge] tone and label without inventing any
/// "gateway confirmed device X" state the cloud API does not actually expose.
Future<void> _pumpGateway(WidgetTester tester, CloudStatus status) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme(AppThemeMode.light),
      home: Scaffold(body: GatewayStatusCard(status: status)),
    ),
  );
}

Future<void> _pumpRuleStatus(
  WidgetTester tester, {
  required AutomationSyncStatus syncStatus,
  required AutomationLastRunStatus runStatus,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme(AppThemeMode.light),
      home: Scaffold(
        body: RuleStatusRow(syncStatus: syncStatus, runStatus: runStatus),
      ),
    ),
  );
}

void main() {
  group('Gateway status card', () {
    testWidgets('online state renders success badge', (tester) async {
      await _pumpGateway(
        tester,
        const CloudStatus.online(
          gatewayId: 'gw-ubuntu-01',
          eventType: 'gateway_online',
          occurredAt: '10:11 05/17/2026',
        ),
      );

      expect(find.text('Gateway online'), findsOneWidget);

      final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
      expect(badge.tone, BadgeTone.success);
      expect(badge.label, 'LOG');
    });

    testWidgets('offline state renders error badge', (tester) async {
      await _pumpGateway(
        tester,
        const CloudStatus.offline(
          detail: 'Cloud reports gateway offline',
          gatewayId: 'gw-ubuntu-01',
        ),
      );

      expect(find.text('Gateway offline'), findsOneWidget);

      final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
      expect(badge.tone, BadgeTone.error);
      expect(badge.label, 'OFF');
    });

    testWidgets(
      'unknown state renders neutral badge without implying gateway confirmation',
      (tester) async {
        await _pumpGateway(
          tester,
          const CloudStatus.unknown(
            detail: 'No gateway status log found in cloud events',
          ),
        );

        expect(find.text('Gateway status unknown'), findsOneWidget);
        // The detail string only references the cloud event log and does not
        // claim the gateway itself has confirmed any device state.
        expect(
          find.text('No gateway status log found in cloud events'),
          findsOneWidget,
        );

        final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
        expect(badge.tone, BadgeTone.neutral);
        expect(badge.label, 'CHECK');
      },
    );
  });

  group('Rule status row', () {
    testWidgets('syncing state renders pending label with neutral tone', (
      tester,
    ) async {
      await _pumpRuleStatus(
        tester,
        syncStatus: AutomationSyncStatus.pending,
        runStatus: AutomationLastRunStatus.neverRun,
      );

      // Two badges: sync + last-run. Find by label so the test pins both.
      final pendingBadge = tester.widget<StatusBadge>(
        find.widgetWithText(StatusBadge, 'PENDING'),
      );
      expect(pendingBadge.tone, BadgeTone.neutral);

      final runBadge = tester.widget<StatusBadge>(
        find.widgetWithText(StatusBadge, 'NEVER RUN'),
      );
      expect(runBadge.tone, BadgeTone.neutral);
    });

    testWidgets(
      'synced + executed state renders success on both badges',
      (tester) async {
        await _pumpRuleStatus(
          tester,
          syncStatus: AutomationSyncStatus.synced,
          runStatus: AutomationLastRunStatus.executed,
        );

        final syncBadge = tester.widget<StatusBadge>(
          find.widgetWithText(StatusBadge, 'SYNCED'),
        );
        expect(syncBadge.tone, BadgeTone.success);

        final runBadge = tester.widget<StatusBadge>(
          find.widgetWithText(StatusBadge, 'EXECUTED'),
        );
        expect(runBadge.tone, BadgeTone.success);
      },
    );

    testWidgets('failed sync + failed run both render error badge', (
      tester,
    ) async {
      await _pumpRuleStatus(
        tester,
        syncStatus: AutomationSyncStatus.failed,
        runStatus: AutomationLastRunStatus.failed,
      );

      // Both sync- and run-status badges share the "FAILED" label, so use
      // widgetList to assert both are error-toned.
      final allFailed = tester
          .widgetList<StatusBadge>(find.widgetWithText(StatusBadge, 'FAILED'))
          .toList();
      expect(allFailed, hasLength(2));
      expect(allFailed.every((b) => b.tone == BadgeTone.error), isTrue);
    });
  });
}
