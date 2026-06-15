import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zigbee_smart_building/domain/models/automation_rule.dart';
import 'package:zigbee_smart_building/domain/models/cloud_status.dart';
import 'package:zigbee_smart_building/domain/models/command_result.dart';
import 'package:zigbee_smart_building/domain/models/device_power.dart';
import 'package:zigbee_smart_building/domain/models/event_log.dart';
import 'package:zigbee_smart_building/domain/models/light_scene.dart';
import 'package:zigbee_smart_building/domain/models/room.dart';
import 'package:zigbee_smart_building/domain/models/smart_device.dart';
import 'package:zigbee_smart_building/domain/repositories/automation_repository.dart';
import 'package:zigbee_smart_building/domain/repositories/device_repository.dart';
import 'package:zigbee_smart_building/domain/repositories/scene_repository.dart';
import 'package:zigbee_smart_building/l10n/app_localizations.dart';
import 'package:zigbee_smart_building/ui/core/theme/app_theme.dart';
import 'package:zigbee_smart_building/ui/features/automation/view_models/automation_view_model.dart';
import 'package:zigbee_smart_building/ui/features/automation/widgets/create_rule_sheet.dart';
import 'package:zigbee_smart_building/ui/features/automation/widgets/schedule_trigger_section.dart';
import 'package:zigbee_smart_building/ui/features/devices/view_models/device_dashboard_view_model.dart';

void main() {
  testWidgets('rule kind labels follow the active locale', (tester) async {
    await _pumpSheet(tester, locale: const Locale('vi'));

    // The rule-type selector replaces the old quick-template grid.
    expect(find.text('Thiết bị kích hoạt'), findsWidgets);
    expect(find.text('Theo lịch'), findsOneWidget);
  });

  testWidgets('schedule + turn on + weekdays saves direct light rule', (
    tester,
  ) async {
    final repository = await _pumpSheet(tester);

    await tester.enterText(find.byType(TextField).first, 'Weekday lights on');
    await _tapVisible(tester, find.byKey(const ValueKey('rule-kind-schedule')));
    await _tapVisible(tester, find.byKey(const ValueKey('schedule-action-on')));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('schedule-mode-weekdays')),
    );
    await _tapVisible(tester, find.text('Lab Light'));
    await tester.tap(find.text('Save rule'));
    await tester.pump();

    final draft = repository.created.single;
    expect(draft.scheduleCron, '0 7 * * 1-5');
    expect(draft.trigger, isA<ScheduleAutomationTrigger>());
    expect(
      (draft.actions.single as DeviceCommandAutomationAction).command,
      AutomationActionCommand.on,
    );
  });

  testWidgets('schedule rule tab shows a humanized preview', (tester) async {
    await _pumpSheet(tester);

    await tester.enterText(find.byType(TextField).first, 'Preview schedule');
    await _tapVisible(tester, find.byKey(const ValueKey('rule-kind-schedule')));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('schedule-mode-weekdays')),
    );
    await _tapVisible(tester, find.text('Lab Light'));
    await tester.pumpAndSettle();

    expect(find.text('PREVIEW'), findsOneWidget);
    expect(
      find.text('Every weekday at 07:00, turn Lab Light on.'),
      findsOneWidget,
    );
  });

  testWidgets('switching rule kind clears visible selections', (tester) async {
    await _pumpSheet(tester);

    await tester.enterText(find.byType(TextField).first, 'Schedule reset');
    await _tapVisible(tester, find.byKey(const ValueKey('rule-kind-schedule')));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('schedule-mode-weekdays')),
    );
    await _tapVisible(tester, find.text('Lab Light'));

    // Back to the device-trigger kind: the schedule section is gone.
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('rule-kind-deviceTrigger')),
    );
    expect(find.byKey(const ValueKey('schedule-mode-weekdays')), findsNothing);

    // Returning to schedule starts from the default mode (Daily), not Weekdays.
    await _tapVisible(tester, find.byKey(const ValueKey('rule-kind-schedule')));
    final weekdaysChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('schedule-mode-weekdays')),
    );
    expect(weekdaysChip.selected, isFalse);
    final dailyChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('schedule-mode-daily')),
    );
    expect(dailyChip.selected, isTrue);
  });

  testWidgets('invalid custom cron disables Save and uses form error area', (
    tester,
  ) async {
    await _pumpSheet(tester);

    await tester.enterText(find.byType(TextField).first, 'Invalid cron rule');
    await _tapVisible(tester, find.byKey(const ValueKey('rule-kind-schedule')));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('schedule-mode-custom')),
    );
    await tester.enterText(find.byKey(const Key('raw-cron-field')), 'bad cron');
    await tester.pump();
    await _tapVisible(tester, find.text('Lab Light'));

    final saveButton = find.ancestor(
      of: find.text('Save rule'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    expect(find.byKey(const Key('form-validation-message')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ScheduleTriggerSection),
        matching: find.text('Enter a valid five-field cron expression'),
      ),
      findsNothing,
    );
  });

  testWidgets('schedule + turn off + weekly Sunday + scene saves activation', (
    tester,
  ) async {
    final repository = await _pumpSheet(tester);

    await tester.enterText(find.byType(TextField).first, 'Sunday lights off');
    await _tapVisible(tester, find.byKey(const ValueKey('rule-kind-schedule')));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('schedule-action-off')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('schedule-mode-weekly')),
    );
    await _tapVisible(tester, find.byKey(const ValueKey('schedule-weekday-0')));
    await _tapVisible(tester, find.text('Scene'));
    await _tapVisible(tester, find.text('Lab all off'));
    await tester.tap(find.text('Save rule'));
    await tester.pump();

    final draft = repository.created.single;
    expect(draft.scheduleCron, '0 7 * * 0');
    expect(draft.actions.single, isA<SceneActivateAutomationAction>());
  });
}

Future<_FakeAutomationRepository> _pumpSheet(
  WidgetTester tester, {
  Locale? locale,
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repository = _FakeAutomationRepository();
  final automation = AutomationViewModel(
    repository: repository,
    sceneRepository: _FakeSceneRepository(),
  );
  await automation.load();

  final dashboard = DeviceDashboardViewModel(
    repository: _FakeDeviceRepository(),
  );
  await dashboard.load();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: automation),
        ChangeNotifierProvider.value(value: dashboard),
      ],
      child: MaterialApp(
        theme: AppTheme.theme(AppThemeMode.dark),
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CreateRuleSheet()),
      ),
    ),
  );
  await tester.pump();
  return repository;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

class _FakeAutomationRepository implements AutomationRepository {
  final List<AutomationRuleDraft> created = [];

  @override
  Future<List<AutomationRule>> fetchRules() async => const [];

  @override
  Future<AutomationRule> createRule(AutomationRuleDraft draft) async {
    created.add(draft);
    return AutomationRule(
      id: 'rule-${created.length}',
      name: draft.name,
      enabled: draft.enabled,
      trigger: draft.trigger,
      actions: draft.actions,
      syncStatus: AutomationSyncStatus.synced,
      lastRunStatus: AutomationLastRunStatus.neverRun,
    );
  }

  @override
  Future<AutomationRule> fetchRule(String ruleId) {
    throw UnimplementedError();
  }

  @override
  Future<AutomationRule> enableRule(String ruleId) {
    throw UnimplementedError();
  }

  @override
  Future<AutomationRule> disableRule(String ruleId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteRule(String ruleId) {
    throw UnimplementedError();
  }
}

class _FakeSceneRepository implements SceneRepository {
  @override
  SceneAvailability get lastAvailability => SceneAvailability.available;

  @override
  Future<List<LightScene>> fetchScenes() async {
    return const [
      LightScene(
        groupId: 'group-lab',
        sceneId: 'scene-all-off',
        label: 'Lab all off',
        deviceIds: ['light-1'],
      ),
    ];
  }
}

class _FakeDeviceRepository implements DeviceRepository {
  @override
  Future<CloudStatus> fetchCloudStatus() async => const CloudStatus.online();

  @override
  Future<List<SmartDevice>> fetchDevices() async {
    return const [
      SmartDevice(
        id: 'light-1',
        deviceType: 'light',
        name: 'Lab Light',
        isOnline: true,
        power: DevicePower.on,
      ),
    ];
  }

  @override
  Future<List<EventLog>> fetchEvents({String? deviceId}) async => const [];

  @override
  Future<CommandResult> sendLightPowerCommand({
    required String deviceId,
    required DevicePower target,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SmartDevice> renameDeviceName({
    required String deviceId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Room>> fetchRooms() async => const [];

  @override
  Future<Room> createRoom(String name) {
    throw UnimplementedError();
  }

  @override
  Future<Room> renameRoom({required String roomId, required String name}) {
    throw UnimplementedError();
  }

  @override
  Future<Room> deleteRoom(String roomId) {
    throw UnimplementedError();
  }

  @override
  Future<SmartDevice> moveDeviceToRoom({
    required String deviceId,
    required String roomId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CommandResult> fetchCommand(String commandId) {
    throw UnimplementedError();
  }
}
