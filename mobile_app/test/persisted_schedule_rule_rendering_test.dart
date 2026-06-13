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
    expect(find.text('0 7 * * 1-5'), findsOneWidget);
    expect(find.text('light-1'), findsOneWidget);
    expect(find.text('Turn on'), findsOneWidget);
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
    expect(find.text('0 22 * * 0'), findsOneWidget);
    expect(find.text('group-lab / scene-all-off'), findsOneWidget);
    expect(find.text('Activate'), findsOneWidget);
  });
}

Widget _buildCard(AutomationRule rule) {
  return MaterialApp(
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
