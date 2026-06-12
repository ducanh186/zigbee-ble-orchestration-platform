# Mobile Light Scenes and Schedule Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add schedule-on/off rule templates, cron presets/raw cron input, and a light-only Scene picker while preserving direct-light schedules when Scene support is unavailable.

**Architecture:** Mobile consumes Cloud schedule and Scene contracts through typed domain/repository models. Schedule UI serializes a top-level cron trigger; action selection is a tagged choice between one direct light and one Cloud-provided light Scene.

**Tech Stack:** Flutter/Dart, Provider, HTTP API client, ARB localization keys supplied by foundation, flutter_test.

---

## Ownership

This agent owns Mobile schedule templates, cron picker, Scene models/repository/API/UI, direct-light fallback, Mobile tests, and a non-overlapping Scene handoff document. It must not implement Cloud cron execution, Environment condition UI, or edit shared ARB files.

### Task 1: Add Schedule and Scene Domain Models

**Files:**
- Modify: `mobile_app/lib/domain/models/automation_rule.dart`
- Create: `mobile_app/lib/domain/models/light_scene.dart`
- Test: `mobile_app/test/automation_model_test.dart`
- Test: `mobile_app/test/light_scene_model_test.dart`

- [ ] **Step 1: Write failing schedule/scene model tests**

```dart
test('schedule trigger serializes top-level cron contract', () {
  const trigger = ScheduleAutomationTrigger(cron: '0 7 * * 1-5');
  expect(trigger.toJson(), {'type': 'schedule'});
  expect(trigger.triggerType, AutomationTriggerType.schedule);
  expect(trigger.cron, '0 7 * * 1-5');
});


test('scene action serializes group and scene ids', () {
  const action = SceneActivateAutomationAction(
    groupId: 'group-lab',
    sceneId: 'scene-all-on',
  );
  expect(action.toJson(), {
    'type': 'scene_activate',
    'group_id': 'group-lab',
    'scene_id': 'scene-all-on',
  });
});


test('light scene parses Cloud tuple', () {
  final scene = LightScene.fromJson({
    'group_id': 'group-lab',
    'scene_id': 'scene-all-on',
    'label': 'Lab all on',
    'device_ids': ['light-1', 'light-2'],
  });
  expect(scene.deviceIds, ['light-1', 'light-2']);
});
```

- [ ] **Step 2: Implement models**

```dart
final class ScheduleAutomationTrigger extends AutomationTrigger {
  const ScheduleAutomationTrigger({required this.cron});
  final String cron;

  @override
  AutomationTriggerType get triggerType => AutomationTriggerType.schedule;

  @override
  Map<String, Object?> toJson() => const {'type': 'schedule'};
}


final class SceneActivateAutomationAction extends AutomationAction {
  const SceneActivateAutomationAction({
    required this.groupId,
    required this.sceneId,
  });

  final String groupId;
  final String sceneId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'scene_activate',
    'group_id': groupId,
    'scene_id': sceneId,
  };
}


class LightScene {
  const LightScene({
    required this.groupId,
    required this.sceneId,
    required this.label,
    required this.deviceIds,
  });

  final String groupId;
  final String sceneId;
  final String label;
  final List<String> deviceIds;
}
```

Extend `AutomationRuleTemplate` with `scheduleOn` and `scheduleOff`.

- [ ] **Step 3: Run tests and commit**

```powershell
Push-Location mobile_app
rtk flutter test test/automation_model_test.dart test/light_scene_model_test.dart
Pop-Location
rtk git add mobile_app/lib/domain/models/automation_rule.dart mobile_app/lib/domain/models/light_scene.dart mobile_app/test/automation_model_test.dart mobile_app/test/light_scene_model_test.dart
rtk git commit -m "feat: model schedule and light scene actions"
```

### Task 2: Add the Scene Repository and API Client

**Files:**
- Create: `mobile_app/lib/domain/repositories/scene_repository.dart`
- Create: `mobile_app/lib/data/repositories/remote_scene_repository.dart`
- Modify: `mobile_app/lib/data/services/api_client.dart`
- Test: `mobile_app/test/remote_scene_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

```dart
test('fetchScenes maps light-only scene tuples', () async {
  api.enqueueJson([
    {
      'group_id': 'group-lab',
      'scene_id': 'scene-on',
      'label': 'Lab lights on',
      'device_ids': ['light-1', 'light-2'],
    },
  ]);
  final scenes = await repository.fetchScenes();
  expect(api.lastPath, '/api/scenes');
  expect(scenes.single.label, 'Lab lights on');
});


test('404 scene endpoint becomes unavailable result', () async {
  api.enqueueError(statusCode: 404, body: {'detail': 'Not found'});
  final result = await repository.fetchScenes();
  expect(result, isEmpty);
  expect(repository.lastAvailability, SceneAvailability.unavailable);
});
```

- [ ] **Step 2: Implement explicit availability**

```dart
enum SceneAvailability { available, empty, unavailable }

abstract interface class SceneRepository {
  SceneAvailability get lastAvailability;
  Future<List<LightScene>> fetchScenes();
}
```

`RemoteSceneRepository` maps 404/501 to `unavailable`, a successful empty list to `empty`, and other failures through `friendlyErrorMessage`. Never return mock production scenes.

- [ ] **Step 3: Run tests and commit**

```powershell
Push-Location mobile_app
rtk flutter test test/remote_scene_repository_test.dart
Pop-Location
rtk git add mobile_app/lib/domain/repositories/scene_repository.dart mobile_app/lib/data/repositories/remote_scene_repository.dart mobile_app/lib/data/services/api_client.dart mobile_app/test/remote_scene_repository_test.dart
rtk git commit -m "feat: fetch light scenes from cloud"
```

### Task 3: Add Scene State to the Automation View Model

**Files:**
- Modify: `mobile_app/lib/ui/features/automation/view_models/automation_view_model.dart`
- Modify: dependency wiring in `mobile_app/lib/main.dart`
- Test: `mobile_app/test/automation_view_model_test.dart`

- [ ] **Step 1: Write failing state tests**

```dart
test('loads scenes without blocking automation rules', () async {
  final viewModel = AutomationViewModel(
    repository: automationRepository,
    sceneRepository: sceneRepository,
  );
  await viewModel.load();
  expect(viewModel.rules, isNotEmpty);
  expect(viewModel.scenes, isNotEmpty);
});


test('scene endpoint unavailable preserves direct light flow', () async {
  sceneRepository.availability = SceneAvailability.unavailable;
  final viewModel = buildViewModel();
  await viewModel.load();
  expect(viewModel.sceneAvailability, SceneAvailability.unavailable);
  expect(viewModel.errorMessage, isNull);
});
```

- [ ] **Step 2: Implement non-blocking scene loading**

Load automation rules and scenes independently. A Scene endpoint outage updates `sceneAvailability` but does not set the whole Automation tab error or disable direct-light rule creation.

- [ ] **Step 3: Run tests and commit**

```powershell
Push-Location mobile_app
rtk flutter test test/automation_view_model_test.dart
Pop-Location
rtk git add mobile_app/lib/ui/features/automation/view_models/automation_view_model.dart mobile_app/lib/main.dart mobile_app/test/automation_view_model_test.dart
rtk git commit -m "feat: expose light scenes to automation UI"
```

### Task 4: Build the Cron Picker

**Files:**
- Create: `mobile_app/lib/ui/features/automation/widgets/schedule_trigger_section.dart`
- Test: `mobile_app/test/schedule_trigger_section_test.dart`

- [ ] **Step 1: Write failing preset tests**

```dart
testWidgets('weekday 07:00 preset emits canonical cron', (tester) async {
  ScheduleSelection? selected;
  await tester.pumpWidget(
    buildSection(onChanged: (value) => selected = value),
  );
  await tester.tap(find.text('Every weekday 07:00'));
  await tester.pump();
  expect(selected?.cron, '0 7 * * 1-5');
});


testWidgets('raw cron rejects non-five-field input', (tester) async {
  await tester.pumpWidget(buildSection());
  await tester.tap(find.text('Custom cron'));
  await tester.enterText(find.byKey(const Key('raw-cron-field')), 'bad cron');
  await tester.pump();
  expect(find.text('Enter a valid five-field cron expression'), findsOneWidget);
});
```

- [ ] **Step 2: Implement presets and raw fallback**

```dart
const schedulePresets = <CronPreset>[
  CronPreset(id: 'weekday_0700', cron: '0 7 * * 1-5'),
  CronPreset(id: 'sunday_2200', cron: '0 22 * * 0'),
  CronPreset(id: 'every_6_hours', cron: '0 */6 * * *'),
];
```

Client validation checks exactly five non-empty fields. Cloud remains authoritative and can still return 422. Do not add explanatory helper text below the field; render one form-level validation message.

- [ ] **Step 3: Run tests and commit**

```powershell
Push-Location mobile_app
rtk flutter test test/schedule_trigger_section_test.dart
Pop-Location
rtk git add mobile_app/lib/ui/features/automation/widgets/schedule_trigger_section.dart mobile_app/test/schedule_trigger_section_test.dart
rtk git commit -m "feat: add cron schedule picker"
```

### Task 5: Build the Light-or-Scene Target Picker

**Files:**
- Create: `mobile_app/lib/ui/features/automation/widgets/scene_target_section.dart`
- Test: `mobile_app/test/scene_target_section_test.dart`

- [ ] **Step 1: Write failing target-mode tests**

```dart
testWidgets('direct light remains selectable when scenes are unavailable', (
  tester,
) async {
  await tester.pumpWidget(
    buildTargetSection(
      availability: SceneAvailability.unavailable,
      lights: [lightDevice()],
    ),
  );
  expect(find.text('Direct light'), findsOneWidget);
  expect(find.text('No scenes available'), findsOneWidget);
  expect(find.text('Lab Light'), findsOneWidget);
});


testWidgets('scene selection emits scene action', (tester) async {
  SceneActivateAutomationAction? action;
  await tester.pumpWidget(
    buildTargetSection(
      availability: SceneAvailability.available,
      scenes: [labScene()],
      onSceneChanged: (value) => action = value,
    ),
  );
  await tester.tap(find.text('Scene'));
  await tester.tap(find.text('Lab all on'));
  expect(action?.sceneId, 'scene-all-on');
});
```

- [ ] **Step 2: Implement tagged target selection**

Only one target mode is active:

```dart
sealed class ScheduleTargetSelection {
  const ScheduleTargetSelection();
}

final class DirectLightTarget extends ScheduleTargetSelection {
  const DirectLightTarget(this.deviceId);
  final String deviceId;
}

final class SceneTarget extends ScheduleTargetSelection {
  const SceneTarget(this.groupId, this.sceneId);
  final String groupId;
  final String sceneId;
}
```

Scene mode lists Cloud tuples only. Unsupported/unavailable Scene mode displays `No scenes available` and keeps Direct light enabled.

- [ ] **Step 3: Run tests and commit**

```powershell
Push-Location mobile_app
rtk flutter test test/scene_target_section_test.dart
Pop-Location
rtk git add mobile_app/lib/ui/features/automation/widgets/scene_target_section.dart mobile_app/test/scene_target_section_test.dart
rtk git commit -m "feat: select direct light or scene target"
```

### Task 6: Integrate Schedule Templates into New Rule

**Files:**
- Modify: `mobile_app/lib/ui/features/automation/widgets/create_rule_sheet.dart`
- Modify: `mobile_app/lib/ui/features/automation/widgets/template_card.dart`
- Modify: `mobile_app/lib/ui/features/automation/widgets/automation_visuals.dart`
- Test: `mobile_app/test/create_schedule_rule_test.dart`

- [ ] **Step 1: Write failing end-to-end widget tests**

```dart
testWidgets('schedule_on preset saves direct light rule', (tester) async {
  final repository = FakeAutomationRepository();
  await tester.pumpWidget(buildScheduleRuleApp(repository: repository));
  await tester.tap(find.text('Schedule on'));
  await tester.tap(find.text('Every weekday 07:00'));
  await tester.tap(find.text('Lab Light'));
  await tester.tap(find.text('Save rule'));
  await tester.pumpAndSettle();

  final draft = repository.created.single;
  expect(draft.scheduleCron, '0 7 * * 1-5');
  expect(draft.trigger, isA<ScheduleAutomationTrigger>());
  expect(
    (draft.actions.single as DeviceCommandAutomationAction).command,
    AutomationActionCommand.on,
  );
});


testWidgets('schedule_off saves scene activation target', (tester) async {
  final repository = FakeAutomationRepository();
  await tester.pumpWidget(
    buildScheduleRuleApp(repository: repository, scenes: [labOffScene()]),
  );
  await tester.tap(find.text('Schedule off'));
  await tester.tap(find.text('Every Sunday 22:00'));
  await tester.tap(find.text('Scene'));
  await tester.tap(find.text('Lab all off'));
  await tester.tap(find.text('Save rule'));
  await tester.pumpAndSettle();

  expect(repository.created.single.actions.single, isA<SceneActivateAutomationAction>());
});
```

- [ ] **Step 2: Compose schedule-only sections**

When `scheduleOn` or `scheduleOff` is selected:

- Hide event-device and Environment controls.
- Show `ScheduleTriggerSection`.
- Show target type and corresponding direct-light/Scene picker.
- Force direct light command to `on` or `off` from the selected template.
- Build `AutomationRuleDraft` with `ScheduleAutomationTrigger`, `scheduleCron`, and one action.

Existing event templates must retain their current UI and serialization.

- [ ] **Step 3: Run tests and commit**

```powershell
Push-Location mobile_app
rtk flutter test test/create_schedule_rule_test.dart test/create_rule_sheet_test.dart test/remote_automation_repository_test.dart
Pop-Location
rtk git add mobile_app/lib/ui/features/automation/widgets/create_rule_sheet.dart mobile_app/lib/ui/features/automation/widgets/template_card.dart mobile_app/lib/ui/features/automation/widgets/automation_visuals.dart mobile_app/test/create_schedule_rule_test.dart
rtk git commit -m "feat: create scheduled light and scene rules"
```

### Task 7: Document the Scene Dependency

**Files:**
- Create: `docs/handoffs/gateway-light-scenes-contract.md`

- [ ] **Step 1: Document Cloud and Gateway responsibilities**

Explain in beginner-friendly terms:

```text
Cloud owns durable Scene definitions:
(group_id, scene_id, label, device_ids)

Mobile reads Scene definitions and writes:
{"type":"scene_activate","group_id":"...","scene_id":"..."}

Gateway must:
- receive synced light-only Scene definitions
- reject non-light members
- execute scene.activate against the synced lights
- report explicit unsupported_scene / scene_not_found failures
```

State that direct-light schedules do not depend on Groups/Scenes and remain production-usable.

- [ ] **Step 2: Commit**

```powershell
rtk git add -f docs/handoffs/gateway-light-scenes-contract.md
rtk git commit -m "docs: hand off light scene execution contract"
```

### Task 8: Verify Agent 66

- [ ] **Step 1: Run focused tests**

```powershell
Push-Location mobile_app
rtk flutter test test/automation_model_test.dart test/light_scene_model_test.dart test/remote_scene_repository_test.dart test/automation_view_model_test.dart test/schedule_trigger_section_test.dart test/scene_target_section_test.dart test/create_schedule_rule_test.dart test/create_rule_sheet_test.dart test/remote_automation_repository_test.dart
Pop-Location
```

- [ ] **Step 2: Run analyzer**

```powershell
Push-Location mobile_app
rtk flutter analyze
Pop-Location
```

- [ ] **Step 3: Return evidence**

Return commits, test results, direct-light fallback proof, the exact Cloud Scene endpoint assumption, and the remaining Gateway Scene dependency. Do not claim Scene execution works end-to-end until Gateway support exists.
