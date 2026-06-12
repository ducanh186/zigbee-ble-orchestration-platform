# Shared Foundation and Agent Dispatch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create one verified foundation commit that removes shared Cloud and Mobile assumptions, then branch and dispatch three isolated feature agents without overlapping ownership.

**Architecture:** The foundation keeps existing event automations wire-compatible while introducing typed trigger/action models, a reusable Cloud command execution service, and a compositional Mobile rule form. It also reserves all new feature localization keys so Environment and Schedule/Scene agents can work without concurrently editing ARB files.

**Tech Stack:** Python 3.12, FastAPI, Pydantic v2, SQLAlchemy async, pytest, Flutter/Dart, Provider, flutter_test, Git worktrees.

---

## File Map

- Create: `cloud/app/command_execution.py` - shared command validation, persistence, and MQTT publication.
- Modify: `cloud/app/routers/commands.py` - delegate REST commands to the shared service.
- Modify: `cloud/app/schemas.py` - discriminated event, sensor-threshold, schedule, device-action, and scene-action schemas.
- Test: `cloud/tests/test_commands.py` - service/route regression tests.
- Test: `cloud/tests/test_schemas.py` - typed automation payload validation tests.
- Modify: `mobile_app/lib/domain/models/automation_rule.dart` - typed triggers/actions and backward-compatible parsing values.
- Modify: `mobile_app/lib/data/models/automation_api_model.dart` - serialize and parse all typed shapes.
- Create: `mobile_app/lib/ui/features/automation/widgets/event_trigger_section.dart` - extracted existing event picker.
- Create: `mobile_app/lib/ui/features/automation/widgets/direct_light_target_section.dart` - extracted existing light picker.
- Modify: `mobile_app/lib/ui/features/automation/widgets/create_rule_sheet.dart` - shared shell and draft submission only.
- Modify: `mobile_app/lib/l10n/app_en.arb` - reserve new Environment, Schedule, and Scene English keys.
- Modify: `mobile_app/lib/l10n/app_vi.arb` - Vietnamese mappings for the same keys.
- Test: `mobile_app/test/automation_model_test.dart` - typed model serialization tests.
- Test: `mobile_app/test/create_rule_sheet_test.dart` - unchanged event-rule flow after extraction.

### Task 1: Create the Feature Foundation Branch

**Files:**
- Verify: repository root

- [ ] **Step 1: Confirm the source commit**

Run:

```powershell
rtk proxy git rev-parse HEAD
rtk proxy git rev-parse origin/main
```

Expected: both commands print `4f6e2d97055b75a35958a29f87dcb0a09fa0671c`.

- [ ] **Step 2: Create the feature branch**

Run:

```powershell
rtk git switch -c feat/65-cloud-schedule-trigger-type
```

Expected: current branch is `feat/65-cloud-schedule-trigger-type`.

- [ ] **Step 3: Run focused baselines**

Run:

```powershell
rtk pytest cloud/tests/test_schemas.py cloud/tests/test_commands.py -q
Push-Location mobile_app
rtk flutter test test/remote_automation_repository_test.dart test/automation_view_model_test.dart
Pop-Location
```

Expected: all selected tests pass before foundation changes.

### Task 2: Add Typed Cloud Automation Contracts

**Files:**
- Modify: `cloud/app/schemas.py:317`
- Test: `cloud/tests/test_schemas.py`

- [ ] **Step 1: Write failing schema tests**

Add tests that validate the accepted legacy event payload and reject malformed new payloads:

```python
def test_automation_create_accepts_existing_event_rule():
    body = AutomationCreate(
        name="Motion turns on light",
        trigger_type="event",
        trigger={
            "type": "device_event",
            "device_id": "motion-1",
            "device_type": "motion",
            "event": "occupancy_changed",
            "state": {"occupancy": "occupied"},
        },
        actions=[
            {
                "type": "device_command",
                "device_id": "light-1",
                "device_type": "light",
                "command": "on",
            }
        ],
    )
    assert body.trigger.type == "device_event"


@pytest.mark.parametrize(
    ("trigger", "message"),
    [
        (
            {
                "type": "sensor_threshold",
                "device_id": "env-1",
                "device_type": "environment",
                "metric": "temperature_c",
                "operator": "gte",
                "threshold": 100,
            },
            "less than or equal to 80",
        ),
        ({"type": "schedule"}, "schedule_cron"),
    ],
)
def test_automation_create_rejects_invalid_typed_trigger(trigger, message):
    with pytest.raises(ValidationError, match=message):
        AutomationCreate(
            name="Invalid",
            trigger_type="event",
            trigger=trigger,
            actions=[
                {
                    "type": "device_command",
                    "device_id": "light-1",
                    "device_type": "light",
                    "command": "on",
                }
            ],
        )
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
rtk pytest cloud/tests/test_schemas.py -q
```

Expected: FAIL because `trigger_type` and typed trigger/action models do not exist.

- [ ] **Step 3: Implement discriminated models**

Add explicit Pydantic models and unions while keeping JSON field names unchanged:

```python
class DeviceEventTrigger(BaseModel):
    type: Literal["device_event"] = "device_event"
    device_id: str = Field(min_length=1)
    device_type: Literal["motion", "switch"]
    event: Literal["occupancy_changed", "switch_toggle"]
    state: dict[str, Any] = Field(default_factory=dict)


class SensorThresholdTrigger(BaseModel):
    type: Literal["sensor_threshold"]
    device_id: str = Field(min_length=1)
    device_type: Literal["environment"]
    metric: Literal["temperature_c", "humidity_percent"]
    operator: Literal["gte", "lte"]
    threshold: float

    @model_validator(mode="after")
    def validate_threshold_range(self):
        minimum, maximum = (
            (-20.0, 80.0)
            if self.metric == "temperature_c"
            else (0.0, 100.0)
        )
        if not minimum <= self.threshold <= maximum:
            raise ValueError(
                f"{self.metric} threshold must be between {minimum:g} and {maximum:g}"
            )
        return self


class ScheduleTrigger(BaseModel):
    type: Literal["schedule"]


AutomationTrigger = Annotated[
    DeviceEventTrigger | SensorThresholdTrigger | ScheduleTrigger,
    Field(discriminator="type"),
]


class DeviceCommandAction(BaseModel):
    type: Literal["device_command"] = "device_command"
    device_id: str = Field(min_length=1)
    device_type: Literal["light"]
    command: Literal["on", "off", "toggle"]


class SceneActivateAction(BaseModel):
    type: Literal["scene_activate"]
    group_id: str = Field(min_length=1)
    scene_id: str = Field(min_length=1)


AutomationAction = Annotated[
    DeviceCommandAction | SceneActivateAction,
    Field(discriminator="type"),
]
```

Update `AutomationCreate`, `AutomationUpdate`, and `AutomationOut` to use these types. Add a pre-validator that inserts `type="device_event"` and `type="device_command"` for existing payloads that omit those discriminators.

- [ ] **Step 4: Run tests and verify pass**

Run:

```powershell
rtk pytest cloud/tests/test_schemas.py -q
```

Expected: PASS, including existing schema tests.

- [ ] **Step 5: Commit**

Run:

```powershell
rtk git add cloud/app/schemas.py cloud/tests/test_schemas.py
rtk git commit -m "refactor: type automation trigger and action contracts"
```

### Task 3: Extract Reusable Cloud Command Execution

**Files:**
- Create: `cloud/app/command_execution.py`
- Modify: `cloud/app/routers/commands.py:29`
- Test: `cloud/tests/test_commands.py`

- [ ] **Step 1: Write failing service tests**

```python
@pytest.mark.asyncio
async def test_execute_device_command_persists_before_publish(db_session, light, fake_mqtt):
    command = await execute_device_command(
        db_session,
        device_id=light.id,
        op="set_power",
        target={"power": "on"},
        timeout_ms=5000,
        current_user=None,
    )

    assert command.device_id == light.id
    assert command.status == "accepted"
    assert fake_mqtt.calls[0]["command_id"] == command.id


@pytest.mark.asyncio
async def test_execute_device_command_rejects_unknown_device(db_session, fake_mqtt):
    with pytest.raises(CommandExecutionError) as exc:
        await execute_device_command(
            db_session,
            device_id="missing",
            op="set_power",
            target={"power": "on"},
            timeout_ms=5000,
            current_user=None,
        )
    assert exc.value.status_code == 404
    assert fake_mqtt.calls == []
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
rtk pytest cloud/tests/test_commands.py -q
```

Expected: FAIL because `execute_device_command` does not exist.

- [ ] **Step 3: Implement the shared service**

```python
@dataclass(slots=True)
class CommandExecutionError(Exception):
    status_code: int
    detail: str


async def execute_device_command(
    db: AsyncSession,
    *,
    device_id: str,
    op: str,
    target: dict[str, Any],
    timeout_ms: int,
    current_user: User | None,
) -> Command:
    device = await db.get(Device, device_id)
    if device is None:
        raise CommandExecutionError(404, "Device not found")
    if current_user is not None:
        await ensure_device_manageable(db, device, current_user)

    try:
        mqtt_op, mqtt_target = translate_command_for_gateway(
            device.device_type, op, target
        )
    except (ValueError, ValidationError) as exc:
        raise CommandExecutionError(422, str(exc)) from exc

    command_id = uuid4().hex
    command = Command(
        id=command_id,
        device_id=device_id,
        op=mqtt_op,
        target=mqtt_target,
        status="accepted",
        timeout_ms=timeout_ms,
        expires_at=datetime.now(UTC).replace(tzinfo=None)
        + timedelta(milliseconds=timeout_ms),
    )
    db.add(command)
    await db.commit()
    await db.refresh(command)
    mqtt_service.publish_command(
        command_id=command.id,
        device_id=device_id,
        op=mqtt_op,
        target=mqtt_target,
        timeout_ms=timeout_ms,
    )
    return command
```

Refactor `create_command` to call this service and translate `CommandExecutionError` into `HTTPException`.

- [ ] **Step 4: Run command tests**

Run:

```powershell
rtk pytest cloud/tests/test_commands.py -q
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```powershell
rtk git add cloud/app/command_execution.py cloud/app/routers/commands.py cloud/tests/test_commands.py
rtk git commit -m "refactor: share device command execution"
```

### Task 4: Introduce Typed Mobile Automation Models

**Files:**
- Modify: `mobile_app/lib/domain/models/automation_rule.dart`
- Modify: `mobile_app/lib/data/models/automation_api_model.dart`
- Test: `mobile_app/test/automation_model_test.dart`
- Test: `mobile_app/test/remote_automation_repository_test.dart`

- [ ] **Step 1: Write failing model tests**

```dart
test('serializes a legacy event rule with canonical discriminators', () {
  final draft = AutomationRuleDraft(
    name: 'Motion on',
    enabled: true,
    trigger: const EventAutomationTrigger(
      deviceId: 'motion-1',
      deviceType: AutomationDeviceType.motion,
      event: AutomationTriggerEvent.occupancyChanged,
      state: {'occupancy': 'occupied'},
    ),
    actions: const [
      DeviceCommandAutomationAction(
        deviceId: 'light-1',
        command: AutomationActionCommand.on,
      ),
    ],
  );

  expect(AutomationCreateApiModel.fromDomain(draft).toJson(), {
    'name': 'Motion on',
    'enabled': true,
    'trigger_type': 'event',
    'schedule_cron': null,
    'trigger': {
      'type': 'device_event',
      'device_id': 'motion-1',
      'device_type': 'motion',
      'event': 'occupancy_changed',
      'state': {'occupancy': 'occupied'},
    },
    'actions': [
      {
        'type': 'device_command',
        'device_id': 'light-1',
        'device_type': 'light',
        'command': 'on',
      },
    ],
  });
});
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
Push-Location mobile_app
rtk flutter test test/automation_model_test.dart test/remote_automation_repository_test.dart
Pop-Location
```

Expected: FAIL because typed trigger/action classes do not exist.

- [ ] **Step 3: Replace implicit draft fields with sealed typed models**

```dart
enum AutomationTriggerType { event, schedule }

sealed class AutomationTrigger {
  const AutomationTrigger();
  AutomationTriggerType get triggerType;
  Map<String, Object?> toJson();
}

final class EventAutomationTrigger extends AutomationTrigger {
  const EventAutomationTrigger({
    required this.deviceId,
    required this.deviceType,
    required this.event,
    this.state = const {},
  });

  final String deviceId;
  final AutomationDeviceType deviceType;
  final AutomationTriggerEvent event;
  final Map<String, Object?> state;

  @override
  AutomationTriggerType get triggerType => AutomationTriggerType.event;

  @override
  Map<String, Object?> toJson() => {
    'type': 'device_event',
    'device_id': deviceId,
    'device_type': deviceType.wireValue,
    'event': event.wireValue,
    'state': state,
  };
}

sealed class AutomationAction {
  const AutomationAction();
  Map<String, Object?> toJson();
}

final class DeviceCommandAutomationAction extends AutomationAction {
  const DeviceCommandAutomationAction({
    required this.deviceId,
    required this.command,
  });

  final String deviceId;
  final AutomationActionCommand command;

  @override
  Map<String, Object?> toJson() => {
    'type': 'device_command',
    'device_id': deviceId,
    'device_type': 'light',
    'command': command.wireValue,
  };
}

class AutomationRuleDraft {
  const AutomationRuleDraft({
    required this.name,
    required this.enabled,
    required this.trigger,
    required this.actions,
    this.scheduleCron,
    this.template,
  });

  final String name;
  final bool enabled;
  final AutomationTrigger trigger;
  final List<AutomationAction> actions;
  final String? scheduleCron;
  final AutomationRuleTemplate? template;
}
```

Keep parsing support for existing API payloads without `type`. Add `environment` to `AutomationDeviceType`. Update API serialization to include top-level `trigger_type` and `schedule_cron`.

- [ ] **Step 4: Run model and repository tests**

Run:

```powershell
Push-Location mobile_app
rtk flutter test test/automation_model_test.dart test/remote_automation_repository_test.dart
Pop-Location
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```powershell
rtk git add mobile_app/lib/domain/models/automation_rule.dart mobile_app/lib/data/models/automation_api_model.dart mobile_app/test/automation_model_test.dart mobile_app/test/remote_automation_repository_test.dart
rtk git commit -m "refactor: type mobile automation contracts"
```

### Task 5: Extract Existing Rule Form Sections

**Files:**
- Create: `mobile_app/lib/ui/features/automation/widgets/event_trigger_section.dart`
- Create: `mobile_app/lib/ui/features/automation/widgets/direct_light_target_section.dart`
- Modify: `mobile_app/lib/ui/features/automation/widgets/create_rule_sheet.dart`
- Test: `mobile_app/test/create_rule_sheet_test.dart`

- [ ] **Step 1: Add a failing event-flow widget test**

```dart
testWidgets('existing motion rule still saves after form extraction', (tester) async {
  final repository = FakeAutomationRepository();
  await tester.pumpWidget(buildRuleTestApp(repository: repository));

  await tester.tap(find.text('New rule'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('rule-name-field')), 'Motion on');
  await tester.tap(find.text('Motion Sensor'));
  await tester.tap(find.text('Lab Light'));
  await tester.tap(find.text('Save rule'));
  await tester.pumpAndSettle();

  expect(repository.created.single.trigger, isA<EventAutomationTrigger>());
  expect(repository.created.single.actions, hasLength(1));
});
```

- [ ] **Step 2: Run test and confirm current behavior**

Run:

```powershell
Push-Location mobile_app
rtk flutter test test/create_rule_sheet_test.dart
Pop-Location
```

Expected: FAIL initially because the dedicated test harness and stable keys are missing.

- [ ] **Step 3: Extract the existing sections without changing behavior**

Use typed values at the boundary:

```dart
class EventTriggerSelection {
  const EventTriggerSelection({
    required this.deviceId,
    required this.deviceType,
    required this.event,
    this.state = const {},
  });

  final String deviceId;
  final AutomationDeviceType deviceType;
  final AutomationTriggerEvent event;
  final Map<String, Object?> state;

  EventAutomationTrigger toTrigger() => EventAutomationTrigger(
    deviceId: deviceId,
    deviceType: deviceType,
    event: event,
    state: state,
  );
}
```

`CreateRuleSheet` retains name, enabled state, selected template, and final `AutomationRuleDraft` construction. `EventTriggerSection` owns device/event selection. `DirectLightTargetSection` owns selected light IDs and commands. Do not add Environment, Schedule, or Scene controls in this task.

- [ ] **Step 4: Run widget and regression tests**

Run:

```powershell
Push-Location mobile_app
rtk flutter test test/create_rule_sheet_test.dart test/remote_automation_repository_test.dart test/automation_view_model_test.dart
Pop-Location
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```powershell
rtk git add mobile_app/lib/ui/features/automation/widgets/create_rule_sheet.dart mobile_app/lib/ui/features/automation/widgets/event_trigger_section.dart mobile_app/lib/ui/features/automation/widgets/direct_light_target_section.dart mobile_app/test/create_rule_sheet_test.dart
rtk git commit -m "refactor: split automation rule form sections"
```

### Task 6: Reserve New Feature Localization Keys

**Files:**
- Modify: `mobile_app/lib/l10n/app_en.arb`
- Modify: `mobile_app/lib/l10n/app_vi.arb`
- Modify: generated localization files through Flutter generation
- Test: `mobile_app/test/localization_contract_test.dart`

- [ ] **Step 1: Write a failing localization contract test**

```dart
test('new automation and environment keys exist in both locales', () {
  expect(AppLocalizationsEn().environmentTitle, 'Environment');
  expect(AppLocalizationsVi().environmentTitle, 'Môi trường');
  expect(AppLocalizationsEn().scheduleOnTemplate, 'Schedule on');
  expect(AppLocalizationsVi().scheduleOnTemplate, 'Lịch bật');
  expect(AppLocalizationsEn().noScenesAvailable, 'No scenes available');
  expect(AppLocalizationsVi().noScenesAvailable, 'Không có scene khả dụng');
});
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
Push-Location mobile_app
rtk flutter test test/localization_contract_test.dart
Pop-Location
```

Expected: FAIL because the keys do not exist.

- [ ] **Step 3: Add keys**

Add English-source keys and Vietnamese mappings for:

```text
environmentTitle
temperatureLabel
humidityLabel
zigbeeLocalLabel
sensorConditionLabel
metricLabel
operatorLabel
thresholdLabel
greaterThanOrEqualLabel
lessThanOrEqualLabel
degreesCelsiusUnit
percentUnit
scheduleOnTemplate
scheduleOffTemplate
scheduleTriggerLabel
cronPresetWeekdaySeven
cronPresetSundayTwentyTwo
cronPresetEverySixHours
rawCronLabel
targetTypeLabel
directLightLabel
sceneLabel
noScenesAvailable
sceneUnavailableMessage
invalidCronMessage
```

Run Flutter localization generation:

```powershell
Push-Location mobile_app
rtk flutter gen-l10n
Pop-Location
```

- [ ] **Step 4: Run localization tests**

Run:

```powershell
Push-Location mobile_app
rtk flutter test test/localization_contract_test.dart
Pop-Location
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```powershell
rtk git add mobile_app/lib/l10n mobile_app/test/localization_contract_test.dart
rtk git commit -m "feat: reserve environment schedule and scene copy"
```

### Task 7: Verify and Mark the Foundation Commit

**Files:**
- Verify: all foundation files

- [ ] **Step 1: Run Cloud verification**

```powershell
rtk pytest cloud/tests/test_schemas.py cloud/tests/test_commands.py cloud/tests/test_automations.py -q
```

Expected: PASS.

- [ ] **Step 2: Run Mobile verification**

```powershell
Push-Location mobile_app
rtk flutter analyze
rtk flutter test test/automation_model_test.dart test/create_rule_sheet_test.dart test/remote_automation_repository_test.dart test/automation_view_model_test.dart test/localization_contract_test.dart
Pop-Location
```

Expected: no analyzer errors and all tests pass.

- [ ] **Step 3: Record the foundation SHA**

```powershell
rtk proxy git rev-parse HEAD
```

Expected: one SHA used as the branch point for all three worktrees.

### Task 8: Dispatch Three Isolated Superpowers Agents

**Files:**
- Worktree 1 branch: `feat/107-environment-sensor-automation-ui`
- Worktree 2 branch: `feat/65-cloud-schedule-trigger-type`
- Worktree 3 branch: `feat/66-mobile-scene-picker-schedule-template`

- [ ] **Step 1: Create isolated worktrees**

Use `superpowers:using-git-worktrees`. Branch 65 continues in its existing worktree. Create branches 107 and 66 from the recorded foundation SHA.

- [ ] **Step 2: Give every agent this mandatory skill preamble**

```text
Before editing any file, read these SKILL.md files completely:
1. superpowers:using-superpowers
2. superpowers:test-driven-development
3. superpowers:verification-before-completion

Use superpowers:systematic-debugging for every unexpected test failure.
Follow the attached implementation plan task-by-task.
Do not edit files outside the listed ownership.
Return: root cause, files changed, tests run with results, commit SHAs, and any blocked dependency.
```

- [ ] **Step 3: Dispatch all three agents concurrently**

Attach exactly one approved spec and one implementation plan to each agent:

1. Agent 107: Environment, provisioning, i18n.
2. Agent 65: Cloud schedule worker.
3. Agent 66: Mobile schedule and light scenes.

- [ ] **Step 4: Review results before integration**

For each returned branch:

```powershell
rtk proxy git log --oneline --decorate -10
rtk git diff --check <foundation-sha>...HEAD
```

Expected: scoped commits, no whitespace errors, no unreported shared-file edits.
