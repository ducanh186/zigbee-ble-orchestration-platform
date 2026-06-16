import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/domain/models/automation_rule.dart';
import 'package:zigbee_smart_building/l10n/app_localizations.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/automation/widgets/automation_visuals.dart';
import 'package:zigbee_smart_building/ui/features/automation/widgets/rule_card.dart';

void main() {
  testWidgets('persisted direct-light schedule renders cron and command', (
    tester,
  ) async {
    final rule = _scheduleRule(
      cron: '0 7 * * 1-5',
      action: const DeviceCommandAutomationAction(
        deviceId: 'light-1',
        command: AutomationActionCommand.on,
      ),
    );

    await tester.pumpWidget(_buildCard(rule));

    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.text('Schedule'), findsWidgets);
    // Cron is decoded to a flowing English sentence (device id falls back to
    // itself here since no name map is provided).
    expect(
      find.text('Every weekday at 07:00, turn light-1 on.'),
      findsOneWidget,
    );
  });

  testWidgets('persisted scene schedule renders composite scene identity', (
    tester,
  ) async {
    final rule = _scheduleRule(
      cron: '0 22 * * 0',
      action: const SceneActivateAutomationAction(
        groupId: 'group-lab',
        sceneId: 'scene-all-off',
      ),
    );

    await tester.pumpWidget(_buildCard(rule));

    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(
      find.text('Every Sunday at 22:00, activate scene-all-off.'),
      findsOneWidget,
    );
  });

  testWidgets('vietnamese rule card localizes environment rule sentences', (
    tester,
  ) async {
    const rule = AutomationRule(
      id: 'rule-env',
      name: 'test độ ẩm',
      enabled: true,
      trigger: SensorThresholdAutomationTrigger(
        deviceId: 'env-1',
        metric: EnvironmentMetric.humidity,
        operator: ThresholdOperator.gte,
        threshold: 80,
      ),
      actions: [
        DeviceCommandAutomationAction(
          deviceId: 'light-004f',
          command: AutomationActionCommand.on,
        ),
      ],
      syncStatus: AutomationSyncStatus.synced,
      lastRunStatus: AutomationLastRunStatus.executed,
    );

    await tester.pumpWidget(
      _buildCard(
        rule,
        locale: const Locale('vi'),
        deviceNames: const {
          'env-1': 'cảm biến môi trường',
          'light-004f': 'Light (004f)',
        },
      ),
    );

    expect(find.text('Cảm biến môi trường'), findsOneWidget);
    expect(
      find.text(
        'Khi cảm biến môi trường có độ ẩm từ 80% trở lên, bật Light (004f).',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('When'), findsNothing);
    expect(find.textContaining('humidity is at least'), findsNothing);
  });
}

Widget _buildCard(
  AutomationRule rule, {
  Locale? locale,
  Map<String, String> deviceNames = const {},
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.theme(AppThemeMode.dark),
    home: Scaffold(
      body: RuleCard(
        rule: rule,
        template: AutomationVisuals.templateForRule(rule),
        deviceNames: deviceNames,
      ),
    ),
  );
}

AutomationRule _scheduleRule({
  required String cron,
  required AutomationAction action,
}) {
  return AutomationRule(
    id: 'rule-1',
    name: 'Scheduled rule',
    enabled: true,
    trigger: ScheduleAutomationTrigger(cron: cron),
    actions: [action],
    syncStatus: AutomationSyncStatus.synced,
    lastRunStatus: AutomationLastRunStatus.neverRun,
  );
}
