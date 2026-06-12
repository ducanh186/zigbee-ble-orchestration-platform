# Environment Sensor, Provisioning, and i18n Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Cloud and Mobile fully ready for DHT11 Environment telemetry and threshold-rule authoring, correct Gateway status visibility, remove stale install-code assumptions from Mobile, and localize all user-visible Mobile text.

**Architecture:** Gateway implementation remains an external dependency described by a tracked handoff. Cloud validates and merges partial Environment reports, exposes durable Gateway status, and Mobile renders Environment values for every role while keeping automation mutations parent/admin-only.

**Tech Stack:** FastAPI, Pydantic v2, SQLAlchemy async, MQTT, pytest, Flutter/Dart, Provider, ARB localization, flutter_test.

---

## Ownership

This agent owns Environment Cloud/Mobile behavior, Gateway status, provisioning audit, app-wide i18n replacement, and the Gateway handoff. It must not implement cron scheduling, schedule templates, scene APIs, or scene UI. It may consume typed contracts and localization keys from the foundation commit.

### Task 1: Validate and Merge Partial Environment Reports

**Files:**
- Modify: `cloud/app/schemas.py`
- Modify: `cloud/app/mqtt_client.py`
- Test: `cloud/tests/test_schemas.py`
- Test: `cloud/tests/test_mqtt_client.py`

- [ ] **Step 1: Write failing Environment validation tests**

```python
def test_validate_environment_temperature_report():
    payload = {
        "schema": "sb.v1",
        "msg_id": "msg-1",
        "ts": "2026-06-13T07:00:00Z",
        "tenant_id": "hust",
        "site_id": "lab01",
        "gateway_id": "gw-ubuntu-01",
        "source": "gateway",
        "payload": {
            "device_type": "environment",
            "device_id": "0000000000000052",
            "state": {
                "temperature_c": 28.5,
                "sensor": "dht11",
                "reachable": True,
            },
        },
    }
    validated = validate_reported_payload("environment", payload)
    assert validated["state"]["temperature_c"] == 28.5


def test_validate_environment_rejects_out_of_range_humidity():
    payload = environment_payload(state={"humidity_percent": 101, "reachable": True})
    with pytest.raises(ValidationError):
        validate_reported_payload("environment", payload)
```

- [ ] **Step 2: Run and verify failure**

```powershell
rtk pytest cloud/tests/test_schemas.py -q
```

Expected: FAIL because Environment reported state is unsupported.

- [ ] **Step 3: Add Environment payload models**

```python
class EnvironmentReportedState(BaseModel):
    temperature_c: float | None = Field(default=None, ge=-20, le=80)
    humidity_percent: float | None = Field(default=None, ge=0, le=100)
    sensor: str | None = None
    reachable: bool

    @model_validator(mode="after")
    def require_one_measurement(self):
        if self.temperature_c is None and self.humidity_percent is None:
            raise ValueError("environment state requires a temperature or humidity value")
        return self


class EnvironmentReportedPayload(BaseModel):
    device_type: Literal["environment"]
    device_id: str
    state: EnvironmentReportedState
```

Route `device_type == "environment"` through this model in `validate_reported_payload`.

- [ ] **Step 4: Write failing partial-merge MQTT tests**

```python
@pytest.mark.asyncio
async def test_environment_reports_merge_temperature_and_humidity(
    mqtt_service, db_session_factory, environment_device
):
    mqtt_service._handle_reported(
        environment_topic(environment_device.id),
        environment_envelope(
            environment_device.id,
            {"temperature_c": 28.5, "sensor": "dht11", "reachable": True},
        ),
    )
    await drain_mqtt_tasks()
    mqtt_service._handle_reported(
        environment_topic(environment_device.id),
        environment_envelope(
            environment_device.id,
            {"humidity_percent": 48, "sensor": "dht11", "reachable": True},
        ),
    )
    await drain_mqtt_tasks()

    state = await latest_state_for(environment_device.id)
    assert state.state == {
        "temperature_c": 28.5,
        "humidity_percent": 48,
        "sensor": "dht11",
        "reachable": True,
    }
```

- [ ] **Step 5: Implement merge-before-store**

Inside the async DB write for `_handle_reported`, load the newest `DeviceState` for the same device. For Environment only:

```python
previous = (
    await db.execute(
        select(DeviceState)
        .where(DeviceState.device_id == device_id)
        .order_by(DeviceState.reported_at.desc())
        .limit(1)
    )
).scalar_one_or_none()
merged_state = {
    **(previous.state if previous is not None else {}),
    **validated_inner["state"],
}
```

Store `merged_state`. Do not create zero values when a measurement is absent.

- [ ] **Step 6: Run tests and commit**

```powershell
rtk pytest cloud/tests/test_schemas.py cloud/tests/test_mqtt_client.py -q
rtk git add cloud/app/schemas.py cloud/app/mqtt_client.py cloud/tests/test_schemas.py cloud/tests/test_mqtt_client.py
rtk git commit -m "feat: ingest environment sensor reports"
```

### Task 2: Add a Dedicated Gateway Status API

**Files:**
- Modify: `cloud/app/schemas.py`
- Modify: `cloud/app/routers/gateways.py`
- Test: `cloud/tests/test_gateways.py`

- [ ] **Step 1: Write failing role-visible status tests**

```python
@pytest.mark.asyncio
@pytest.mark.parametrize("headers_factory", ["admin", "parent", "viewer"])
async def test_gateway_status_visible_to_home_roles(
    client, request, headers_factory, gateway_online_event
):
    headers = request.getfixturevalue(f"{headers_factory}_headers")
    response = await client.get("/api/gateways/gw-ubuntu-01/status", headers=headers)
    assert response.status_code == 200
    assert response.json()["state"] == "online"


@pytest.mark.asyncio
async def test_gateway_status_unknown_without_event(client, viewer_headers):
    response = await client.get(
        "/api/gateways/gw-ubuntu-01/status", headers=viewer_headers
    )
    assert response.status_code == 200
    assert response.json()["state"] == "unknown"
```

- [ ] **Step 2: Run and verify failure**

```powershell
rtk pytest cloud/tests/test_gateways.py -q
```

Expected: 404 because the endpoint does not exist.

- [ ] **Step 3: Add response schema and endpoint**

```python
class GatewayStatusOut(BaseModel):
    gateway_id: str
    state: Literal["online", "offline", "unknown"]
    event_type: str | None = None
    occurred_at: datetime | None = None
    detail: str | None = None
```

The endpoint must authenticate any user, verify the configured Gateway belongs to the user's home context, then query Gateway events directly without filtering on `device_id`.

- [ ] **Step 4: Run tests and commit**

```powershell
rtk pytest cloud/tests/test_gateways.py cloud/tests/test_mqtt_gateway_events.py -q
rtk git add cloud/app/schemas.py cloud/app/routers/gateways.py cloud/tests/test_gateways.py
rtk git commit -m "fix: expose gateway status to home roles"
```

### Task 3: Map Environment and Gateway Status in Mobile

**Files:**
- Modify: `mobile_app/lib/domain/models/smart_device.dart`
- Modify: `mobile_app/lib/domain/models/cloud_status.dart`
- Modify: `mobile_app/lib/domain/repositories/device_repository.dart`
- Modify: `mobile_app/lib/data/repositories/remote_device_repository.dart`
- Modify: `mobile_app/lib/ui/features/devices/view_models/device_dashboard_view_model.dart`
- Test: `mobile_app/test/remote_device_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

```dart
test('maps environment state from the device API', () async {
  api.enqueueJson([
    {
      'id': 'env-1',
      'device_type': 'environment',
      'name': 'DHT11',
      'is_online': true,
      'state': {
        'temperature_c': 28.5,
        'humidity_percent': 48,
        'sensor': 'dht11',
        'reachable': true,
      },
    },
  ]);
  final devices = await repository.fetchDevices();
  expect(devices.single.temperatureC, 28.5);
  expect(devices.single.humidityPercent, 48);
});


test('fetchCloudStatus uses dedicated gateway endpoint', () async {
  api.enqueueJson({
    'gateway_id': 'gw-ubuntu-01',
    'state': 'online',
    'event_type': 'gateway_online',
    'occurred_at': '2026-06-13T07:00:00Z',
  });
  final status = await repository.fetchCloudStatus();
  expect(api.lastPath, '/api/gateways/gw-ubuntu-01/status');
  expect(status.state, CloudConnectionState.online);
});
```

- [ ] **Step 2: Add domain helpers**

```dart
bool get isEnvironment => deviceType == 'environment';
double? get temperatureC => _stateNumber('temperature_c');
double? get humidityPercent => _stateNumber('humidity_percent');
String? get sensorName => state['sensor'] as String?;

double? _stateNumber(String key) {
  final value = state[key];
  return value is num ? value.toDouble() : null;
}
```

Replace event-list inference in `fetchCloudStatus` with the dedicated endpoint.

- [ ] **Step 3: Run tests and commit**

```powershell
Push-Location mobile_app
rtk flutter test test/remote_device_repository_test.dart
Pop-Location
rtk git add mobile_app/lib/domain/models/smart_device.dart mobile_app/lib/domain/models/cloud_status.dart mobile_app/lib/domain/repositories/device_repository.dart mobile_app/lib/data/repositories/remote_device_repository.dart mobile_app/lib/ui/features/devices/view_models/device_dashboard_view_model.dart mobile_app/test/remote_device_repository_test.dart
rtk git commit -m "feat: map environment and gateway status"
```

### Task 4: Render Environment Widgets for Every Role

**Files:**
- Create: `mobile_app/lib/ui/features/home/widgets/environment_metric_card.dart`
- Modify: `mobile_app/lib/ui/features/home/views/home_view.dart`
- Test: `mobile_app/test/home_environment_widget_test.dart`

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('viewer sees temperature and humidity widgets', (tester) async {
  await tester.pumpWidget(
    buildHomeTestApp(
      role: UserRole.viewer,
      devices: [environmentDevice(temperature: 28.5, humidity: 48)],
    ),
  );
  expect(find.text('28.5°C'), findsOneWidget);
  expect(find.text('48%'), findsOneWidget);
  expect(find.text('Zigbee local'), findsNWidgets(2));
});


testWidgets('missing measurement renders dash instead of zero', (tester) async {
  await tester.pumpWidget(
    buildHomeTestApp(
      role: UserRole.viewer,
      devices: [environmentDevice(temperature: 28.5)],
    ),
  );
  expect(find.text('—%'), findsOneWidget);
  expect(find.text('0%'), findsNothing);
});
```

- [ ] **Step 2: Implement responsive cards**

`EnvironmentMetricCard` receives label, value, unit, icon, and sensor name. `HomeView` selects the first reachable Environment sensor and renders two cards under an `Environment` section for admin, parent, and viewer. Do not place role checks around this section.

- [ ] **Step 3: Run tests and commit**

```powershell
Push-Location mobile_app
rtk flutter test test/home_environment_widget_test.dart
Pop-Location
rtk git add mobile_app/lib/ui/features/home/widgets/environment_metric_card.dart mobile_app/lib/ui/features/home/views/home_view.dart mobile_app/test/home_environment_widget_test.dart
rtk git commit -m "feat: show environment metrics on home"
```

### Task 5: Add Sensor Threshold Rule Authoring

**Files:**
- Create: `mobile_app/lib/ui/features/automation/widgets/environment_condition_section.dart`
- Modify: `mobile_app/lib/domain/models/automation_rule.dart`
- Modify: `mobile_app/lib/ui/features/automation/widgets/create_rule_sheet.dart`
- Test: `mobile_app/test/create_environment_rule_test.dart`

- [ ] **Step 1: Write failing model and widget tests**

```dart
test('sensor threshold trigger serializes canonical fields', () {
  const trigger = SensorThresholdAutomationTrigger(
    deviceId: 'env-1',
    metric: EnvironmentMetric.temperature,
    operator: ThresholdOperator.gte,
    threshold: 30,
  );
  expect(trigger.toJson(), {
    'type': 'sensor_threshold',
    'device_id': 'env-1',
    'device_type': 'environment',
    'metric': 'temperature_c',
    'operator': 'gte',
    'threshold': 30.0,
  });
});


testWidgets('parent creates temperature threshold rule', (tester) async {
  final repository = FakeAutomationRepository();
  await tester.pumpWidget(
    buildRuleTestApp(
      role: UserRole.parent,
      devices: [environmentDevice(), lightDevice()],
      repository: repository,
    ),
  );
  await tester.tap(find.text('DHT11'));
  await tester.tap(find.text('Temperature'));
  await tester.tap(find.text('>='));
  await tester.enterText(find.byKey(const Key('threshold-field')), '30');
  await tester.tap(find.text('Lab Light'));
  await tester.tap(find.text('Save rule'));
  await tester.pumpAndSettle();
  expect(repository.created.single.trigger, isA<SensorThresholdAutomationTrigger>());
});
```

- [ ] **Step 2: Implement typed condition models**

```dart
enum EnvironmentMetric { temperature, humidity }
enum ThresholdOperator { gte, lte }

final class SensorThresholdAutomationTrigger extends AutomationTrigger {
  const SensorThresholdAutomationTrigger({
    required this.deviceId,
    required this.metric,
    required this.operator,
    required this.threshold,
  });

  final String deviceId;
  final EnvironmentMetric metric;
  final ThresholdOperator operator;
  final double threshold;

  @override
  AutomationTriggerType get triggerType => AutomationTriggerType.event;

  @override
  Map<String, Object?> toJson() => {
    'type': 'sensor_threshold',
    'device_id': deviceId,
    'device_type': 'environment',
    'metric': metric == EnvironmentMetric.temperature
        ? 'temperature_c'
        : 'humidity_percent',
    'operator': operator == ThresholdOperator.gte ? 'gte' : 'lte',
    'threshold': threshold,
  };
}
```

`EnvironmentConditionSection` validates -20..80°C and 0..100%. Show invalid state through field border and one form-level message only. Do not add helper text under fields or toggles.

- [ ] **Step 3: Enforce role behavior**

Viewer/member can see Environment widgets but must not see or invoke New Rule mutation controls. Preserve existing `require_parent_or_admin` Cloud enforcement.

- [ ] **Step 4: Run tests and commit**

```powershell
Push-Location mobile_app
rtk flutter test test/create_environment_rule_test.dart test/create_rule_sheet_test.dart
Pop-Location
rtk git add mobile_app/lib/domain/models/automation_rule.dart mobile_app/lib/ui/features/automation/widgets/create_rule_sheet.dart mobile_app/lib/ui/features/automation/widgets/environment_condition_section.dart mobile_app/test/create_environment_rule_test.dart
rtk git commit -m "feat: author environment threshold rules"
```

### Task 6: Audit Provisioning Install-Code Assumptions

**Files:**
- Verify/Modify: `mobile_app/lib/data/models/provisioning_api_model.dart`
- Verify/Modify: `mobile_app/lib/ui/features/provisioning/views/provisioning_view.dart`
- Test: `mobile_app/test/provisioning_model_test.dart`
- Test: `mobile_app/test/provisioning_view_test.dart`

- [ ] **Step 1: Add regression tests**

```dart
test('QR payload does not require install_code', () {
  final payload = ProvisioningQrPayload.fromJson({
    'eui64': '0000000000000052',
    'device_type': 'environment',
    'model': 'DHT11',
  });
  expect(payload.eui64, '0000000000000052');
});


testWidgets('provisioning form has no install code field', (tester) async {
  await tester.pumpWidget(buildProvisioningTestApp());
  expect(find.textContaining('Install code'), findsNothing);
  expect(find.byKey(const Key('provisioning-room-field')), findsOneWidget);
  expect(find.byKey(const Key('provisioning-manual-qr-field')), findsOneWidget);
});
```

- [ ] **Step 2: Run tests**

```powershell
Push-Location mobile_app
rtk flutter test test/provisioning_model_test.dart test/provisioning_view_test.dart
Pop-Location
```

Expected: tests should pass on current main. If they fail, remove only the stale Mobile `install_code` requirement; do not remove Cloud-side install-code storage or Gateway commissioning delivery.

- [ ] **Step 3: Commit only if code changed**

```powershell
rtk git add mobile_app/lib/data/models/provisioning_api_model.dart mobile_app/lib/ui/features/provisioning/views/provisioning_view.dart mobile_app/test/provisioning_model_test.dart mobile_app/test/provisioning_view_test.dart
rtk git commit -m "fix: keep install code out of mobile provisioning"
```

Root-cause explanation for the PR: install code is now a Cloud-owned commissioning secret; QR identifies the device, while Cloud sends the secret to Gateway during secure commissioning.

### Task 7: Complete the English/Vietnamese i18n Audit

**Files:**
- Modify: `mobile_app/lib/l10n/app_en.arb`
- Modify: `mobile_app/lib/l10n/app_vi.arb`
- Modify: user-facing Dart files under `mobile_app/lib`
- Test: `mobile_app/test/localization_contract_test.dart`
- Test: `mobile_app/test/mobile_error_handling_test.dart`

- [ ] **Step 1: Add an automated hard-coded-copy guard**

Create a test that scans `mobile_app/lib` and fails on new user-visible literal text in widgets and `friendlyErrorMessage` contexts, with a small allowlist for protocol values, IDs, and preview-only fixtures.

- [ ] **Step 2: Replace ASCII Vietnamese and hard-coded English**

English ARB is the source label. Vietnamese ARB contains natural Vietnamese. At minimum replace literals in:

```text
auth_view_model.dart
automation_view_model.dart
device_dashboard_view_model.dart
api_client.dart
home_view.dart
gateway_status_card.dart
create_rule_sheet.dart
automation_rules_view.dart
provisioning_view.dart
device_detail_view.dart
settings_view.dart
```

Pass localized text into presentation widgets instead of calling localization APIs from pure domain models.

- [ ] **Step 3: Regenerate localizations**

```powershell
Push-Location mobile_app
rtk flutter gen-l10n
Pop-Location
```

- [ ] **Step 4: Run tests and commit**

```powershell
Push-Location mobile_app
rtk flutter test test/localization_contract_test.dart test/mobile_error_handling_test.dart
rtk flutter analyze
Pop-Location
rtk git add mobile_app/lib mobile_app/test/localization_contract_test.dart mobile_app/test/mobile_error_handling_test.dart
rtk git commit -m "fix: localize mobile labels and errors"
```

### Task 8: Write the Gateway Environment Handoff

**Files:**
- Create: `docs/handoffs/gateway-environment-sensor-contract.md`
- Local exclude: `.git/info/exclude`

- [ ] **Step 1: Keep the received handoff local-only**

Add this exact line to the local clone's `.git/info/exclude`:

```text
dht11_environment_sensor_local_handoff (1).md
```

Do not edit the shared `.gitignore`.

- [ ] **Step 2: Document the MQTT contract**

The handoff must include:

```text
Topic:
sb/v1/{tenant_id}/{site_id}/{gateway_id}/devices/environment/{device_id}/reported

Conversion:
temperature_c = temperature_c_x100 / 100
humidity_percent = humidity_pct_x100 / 100

Behavior:
- publish only successful measurements
- allow temperature and humidity in separate reports
- never publish fake zero values
- use EUI64/device_id as durable identity, not node_id
- evaluate gte/lte rules on false-to-true transition
```

Include the full `sb.v1` envelope and Gateway build/runtime checks.

- [ ] **Step 3: Commit**

```powershell
rtk git add -f docs/handoffs/gateway-environment-sensor-contract.md
rtk git commit -m "docs: hand off environment gateway contract"
```

### Task 9: Verify Agent 107

- [ ] **Step 1: Cloud tests**

```powershell
rtk pytest cloud/tests/test_schemas.py cloud/tests/test_mqtt_client.py cloud/tests/test_gateways.py cloud/tests/test_mqtt_gateway_events.py -q
```

- [ ] **Step 2: Mobile tests**

```powershell
Push-Location mobile_app
rtk flutter analyze
rtk flutter test test/remote_device_repository_test.dart test/home_environment_widget_test.dart test/create_environment_rule_test.dart test/provisioning_model_test.dart test/provisioning_view_test.dart test/localization_contract_test.dart test/mobile_error_handling_test.dart
Pop-Location
```

- [ ] **Step 3: Return evidence**

Return root causes, commits, exact test results, and the remaining Gateway dependency. Do not claim end-to-end telemetry works until Gateway publishes the agreed topic.
