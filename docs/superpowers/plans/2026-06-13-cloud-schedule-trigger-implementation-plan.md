# Cloud Schedule Trigger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Cloud-owned automation rules execute direct light actions from valid five-field cron schedules, record execution events, and stop immediately when disabled.

**Architecture:** Automation JSON remains backward-compatible while two relational columns identify schedule rules. A minute-aligned asyncio worker evaluates enabled schedule rules in `Asia/Ho_Chi_Minh`, uses the shared command execution service, and records one automation event per due slot.

**Tech Stack:** FastAPI lifespan, SQLAlchemy async, Alembic, croniter, asyncio, pytest/pytest-asyncio, MQTT.

---

## Ownership

This agent owns Cloud migrations, schedule validation, worker lifecycle, command reuse, schedule execution events, Cloud tests, and `docs/AUTOMATION_CONTRACT.md`. It must not edit Mobile UI, Environment ingestion, ARB files, or scene-picker UI.

### Task 1: Introduce Alembic and the Schedule Columns

**Files:**
- Modify: `cloud/requirements.txt`
- Create: `cloud/alembic.ini`
- Create: `cloud/alembic/env.py`
- Create: `cloud/alembic/script.py.mako`
- Create: `cloud/alembic/versions/20260613_01_add_schedule_trigger.py`
- Modify: `cloud/app/models.py`
- Test: `cloud/tests/test_schedule_migration.py`

- [ ] **Step 1: Write a failing model/migration test**

```python
def test_automation_model_has_schedule_columns():
    columns = Automation.__table__.columns
    assert columns["trigger_type"].nullable is False
    assert columns["schedule_cron"].nullable is True


def test_schedule_migration_has_event_server_default():
    module = load_migration("20260613_01_add_schedule_trigger")
    assert module.TRIGGER_TYPE_VALUES == ("event", "schedule")
```

- [ ] **Step 2: Add dependencies**

Add pinned project-compatible versions:

```text
alembic==1.14.0
croniter==6.0.0
```

- [ ] **Step 3: Configure Alembic**

`env.py` imports `Base.metadata` and reads the same database URL as Cloud settings. Support async migration execution with `async_engine_from_config`.

- [ ] **Step 4: Implement the migration**

```python
TRIGGER_TYPE_VALUES = ("event", "schedule")
trigger_type_enum = sa.Enum(
    *TRIGGER_TYPE_VALUES,
    name="automation_trigger_type",
)


def upgrade() -> None:
    trigger_type_enum.create(op.get_bind(), checkfirst=True)
    op.add_column(
        "automations",
        sa.Column(
            "trigger_type",
            trigger_type_enum,
            nullable=False,
            server_default="event",
        ),
    )
    op.add_column(
        "automations",
        sa.Column("schedule_cron", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("automations", "schedule_cron")
    op.drop_column("automations", "trigger_type")
    trigger_type_enum.drop(op.get_bind(), checkfirst=True)
```

Mirror the columns in `Automation`:

```python
trigger_type = Column(
    Enum("event", "schedule", name="automation_trigger_type"),
    nullable=False,
    default="event",
    server_default="event",
)
schedule_cron = Column(Text, nullable=True)
```

- [ ] **Step 5: Run tests and migration**

```powershell
rtk pytest cloud/tests/test_schedule_migration.py -q
rtk alembic -c cloud/alembic.ini upgrade head
```

Expected: tests pass and migration completes on the configured test database.

- [ ] **Step 6: Commit**

```powershell
rtk git add cloud/requirements.txt cloud/alembic.ini cloud/alembic cloud/app/models.py cloud/tests/test_schedule_migration.py
rtk git commit -m "feat: migrate automations for schedule triggers"
```

### Task 2: Validate Five-Field Schedule Rules at API Level

**Files:**
- Modify: `cloud/app/schemas.py`
- Modify: `cloud/app/routers/automations.py`
- Test: `cloud/tests/test_schemas.py`
- Test: `cloud/tests/test_automations.py`

- [ ] **Step 1: Write failing validation tests**

```python
def test_schedule_rule_accepts_weekday_seven_am():
    body = AutomationCreate(
        name="Weekday light",
        trigger_type="schedule",
        schedule_cron="0 7 * * 1-5",
        trigger={"type": "schedule"},
        actions=[device_action("light-1", "on")],
    )
    assert body.schedule_cron == "0 7 * * 1-5"


@pytest.mark.parametrize(
    "cron",
    ["bad cron", "0 7 * *", "0 7 * * 1-5 extra", "0 0 7 * * 1-5"],
)
def test_schedule_rule_rejects_bad_cron(cron):
    with pytest.raises(ValidationError):
        AutomationCreate(
            name="Bad",
            trigger_type="schedule",
            schedule_cron=cron,
            trigger={"type": "schedule"},
            actions=[device_action("light-1", "on")],
        )


def test_event_rule_rejects_schedule_cron():
    with pytest.raises(ValidationError):
        AutomationCreate(
            name="Bad event",
            trigger_type="event",
            schedule_cron="0 7 * * 1-5",
            trigger=device_event_trigger(),
            actions=[device_action("light-1", "on")],
        )
```

- [ ] **Step 2: Implement cross-field validation**

```python
def validate_five_field_cron(value: str) -> str:
    value = value.strip()
    if len(value.split()) != 5 or not croniter.is_valid(value):
        raise ValueError("schedule_cron must be a valid five-field cron expression")
    return value


@model_validator(mode="after")
def validate_trigger_contract(self):
    if self.trigger_type == "schedule":
        if self.trigger.type != "schedule":
            raise ValueError("schedule trigger_type requires trigger.type=schedule")
        if self.schedule_cron is None:
            raise ValueError("schedule trigger_type requires schedule_cron")
        self.schedule_cron = validate_five_field_cron(self.schedule_cron)
    else:
        if self.trigger.type == "schedule":
            raise ValueError("event trigger_type cannot use trigger.type=schedule")
        if self.schedule_cron is not None:
            raise ValueError("event trigger_type requires schedule_cron=null")
    return self
```

Apply the same merged-value validation on update. Persist and return `trigger_type` and `schedule_cron`.

- [ ] **Step 3: Run API tests**

```powershell
rtk pytest cloud/tests/test_schemas.py cloud/tests/test_automations.py -q
```

Expected: invalid cron requests return HTTP 422; event-rule regression tests pass.

- [ ] **Step 4: Commit**

```powershell
rtk git add cloud/app/schemas.py cloud/app/routers/automations.py cloud/tests/test_schemas.py cloud/tests/test_automations.py
rtk git commit -m "feat: validate schedule automation payloads"
```

### Task 3: Build a Reusable Automation Action Executor

**Files:**
- Create: `cloud/app/automation_execution.py`
- Test: `cloud/tests/test_schedule_execution.py`

- [ ] **Step 1: Write failing execution tests**

```python
@pytest.mark.asyncio
async def test_execute_schedule_rule_dispatches_light_action(
    db_session, schedule_rule, light, fake_mqtt
):
    events = await execute_automation_rule(
        db_session,
        schedule_rule,
        scheduled_for=datetime(2026, 6, 15, 7, 0),
    )
    assert len(events) == 1
    assert fake_mqtt.calls[0]["device_id"] == light.id
    assert events[0].event_type == "automation_executed"


@pytest.mark.asyncio
async def test_execute_schedule_rule_records_failed_action(
    db_session, schedule_rule_for_missing_light
):
    events = await execute_automation_rule(
        db_session,
        schedule_rule_for_missing_light,
        scheduled_for=datetime(2026, 6, 15, 7, 0),
    )
    assert events[0].event_type == "automation_failed"
```

- [ ] **Step 2: Implement direct-light execution**

```python
async def execute_automation_rule(
    db: AsyncSession,
    rule: Automation,
    *,
    scheduled_for: datetime,
) -> list[AutomationEvent]:
    created_events: list[AutomationEvent] = []
    for index, action in enumerate(rule.actions):
        if action["type"] != "device_command":
            event = build_failure_event(
                rule,
                scheduled_for,
                index,
                "unsupported_action",
            )
            db.add(event)
            created_events.append(event)
            continue
        try:
            command = await execute_device_command(
                db,
                device_id=action["device_id"],
                op="set_power",
                target={"power": action["command"]},
                timeout_ms=5000,
                current_user=None,
            )
            event = build_success_event(rule, scheduled_for, index, command.id)
        except CommandExecutionError as exc:
            event = build_failure_event(rule, scheduled_for, index, exc.detail)
        db.add(event)
        created_events.append(event)

    rule.last_run_status = (
        "failed"
        if any(event.event_type == "automation_failed" for event in created_events)
        else "executed"
    )
    rule.last_error = next(
        (
            event.payload["error"]
            for event in created_events
            if event.event_type == "automation_failed"
        ),
        None,
    )
    await db.commit()
    return created_events
```

Use the existing `AutomationEvent` model and response contract. Include `scheduled_for`, action index, command ID, and outcome in event payload.

- [ ] **Step 3: Run tests and commit**

```powershell
rtk pytest cloud/tests/test_schedule_execution.py cloud/tests/test_commands.py cloud/tests/test_automation_events.py -q
rtk git add cloud/app/automation_execution.py cloud/tests/test_schedule_execution.py
rtk git commit -m "feat: execute scheduled automation actions"
```

### Task 4: Implement the Minute-Aligned Schedule Worker

**Files:**
- Create: `cloud/app/schedule_worker.py`
- Modify: `cloud/app/config.py`
- Test: `cloud/tests/test_schedule_worker.py`

- [ ] **Step 1: Write failing due-rule tests**

```python
def test_is_due_matches_weekday_seven_in_local_timezone():
    local_time = datetime(2026, 6, 15, 7, 0, tzinfo=ZoneInfo("Asia/Ho_Chi_Minh"))
    assert is_schedule_due("0 7 * * 1-5", local_time)


@pytest.mark.asyncio
async def test_worker_skips_disabled_rule(db_session, disabled_schedule_rule, executor):
    worker = ScheduleWorker(session_factory, executor=executor)
    await worker.run_once(datetime(2026, 6, 15, 7, 0, tzinfo=worker.timezone))
    executor.assert_not_awaited()


@pytest.mark.asyncio
async def test_worker_executes_due_rule_once_per_minute(
    db_session, schedule_rule, executor
):
    worker = ScheduleWorker(session_factory, executor=executor)
    now = datetime(2026, 6, 15, 7, 0, 5, tzinfo=worker.timezone)
    await worker.run_once(now)
    await worker.run_once(now.replace(second=40))
    executor.assert_awaited_once()
```

- [ ] **Step 2: Implement worker**

```python
SCHEDULE_TIMEZONE = ZoneInfo("Asia/Ho_Chi_Minh")


def is_schedule_due(expression: str, local_minute: datetime) -> bool:
    return croniter.match(expression, local_minute.replace(second=0, microsecond=0))


class ScheduleWorker:
    def __init__(self, session_factory, executor=execute_automation_rule):
        self._session_factory = session_factory
        self._executor = executor
        self._last_slots: set[tuple[str, datetime]] = set()
        self.timezone = SCHEDULE_TIMEZONE

    async def run_once(self, now: datetime | None = None) -> None:
        local_now = (now or datetime.now(self.timezone)).astimezone(self.timezone)
        slot = local_now.replace(second=0, microsecond=0)
        async with self._session_factory() as db:
            rules = (
                await db.execute(
                    select(Automation).where(
                        Automation.enabled.is_(True),
                        Automation.trigger_type == "schedule",
                    )
                )
            ).scalars().all()
            for rule in rules:
                key = (rule.id, slot)
                if key in self._last_slots:
                    continue
                if is_schedule_due(rule.schedule_cron, slot):
                    await self._executor(db, rule, scheduled_for=slot.replace(tzinfo=None))
                    self._last_slots.add(key)

    async def run_forever(self) -> None:
        while True:
            await self.run_once()
            now = datetime.now(self.timezone)
            delay = 60 - now.second - now.microsecond / 1_000_000
            await asyncio.sleep(delay)
```

Prune `_last_slots` entries older than two minutes.

- [ ] **Step 3: Run tests and commit**

```powershell
rtk pytest cloud/tests/test_schedule_worker.py -q
rtk git add cloud/app/schedule_worker.py cloud/app/config.py cloud/tests/test_schedule_worker.py
rtk git commit -m "feat: run schedule automations each minute"
```

### Task 5: Wire Worker Lifecycle

**Files:**
- Modify: `cloud/app/main.py`
- Test: `cloud/tests/test_schedule_worker.py`

- [ ] **Step 1: Add lifecycle cancellation test**

```python
@pytest.mark.asyncio
async def test_lifespan_starts_and_cancels_schedule_worker(monkeypatch):
    run_forever = AsyncMock()
    monkeypatch.setattr(schedule_worker, "run_forever", run_forever)
    async with lifespan(app):
        await asyncio.sleep(0)
        run_forever.assert_awaited_once()
    assert no_schedule_task_is_running()
```

- [ ] **Step 2: Start and cancel the task**

Follow the existing command-timeout/offline-reaper pattern:

```python
schedule_task = asyncio.create_task(schedule_worker.run_forever())
try:
    yield
finally:
    schedule_task.cancel()
    with suppress(asyncio.CancelledError):
        await schedule_task
```

- [ ] **Step 3: Run tests and commit**

```powershell
rtk pytest cloud/tests/test_schedule_worker.py cloud/tests/test_timeout.py cloud/tests/test_device_online_lifecycle.py -q
rtk git add cloud/app/main.py cloud/tests/test_schedule_worker.py
rtk git commit -m "feat: manage schedule worker lifecycle"
```

### Task 6: Update the Automation Contract

**Files:**
- Modify: `docs/AUTOMATION_CONTRACT.md`

- [ ] **Step 1: Append the non-breaking extension**

Document:

```json
{
  "name": "Weekday 7am light",
  "enabled": true,
  "trigger_type": "schedule",
  "schedule_cron": "0 7 * * 1-5",
  "trigger": {"type": "schedule"},
  "actions": [
    {
      "type": "device_command",
      "device_id": "light-1",
      "device_type": "light",
      "command": "on"
    }
  ]
}
```

State that this extends the frozen event contract and does not alter existing event payloads. Document five-field cron, `Asia/Ho_Chi_Minh`, disabled-rule behavior, and Cloud ownership.

- [ ] **Step 2: Commit**

```powershell
rtk git add -f docs/AUTOMATION_CONTRACT.md
rtk git commit -m "docs: extend automation contract for schedules"
```

### Task 7: Verify Agent 65

- [ ] **Step 1: Run focused tests**

```powershell
rtk pytest cloud/tests/test_schedule_migration.py cloud/tests/test_schemas.py cloud/tests/test_automations.py cloud/tests/test_schedule_execution.py cloud/tests/test_schedule_worker.py cloud/tests/test_commands.py cloud/tests/test_automation_events.py -q
```

- [ ] **Step 2: Run the full Cloud suite**

```powershell
rtk pytest cloud/tests -q
```

- [ ] **Step 3: Verify acceptance manually with a controlled clock**

Create an enabled rule for `0 7 * * 1-5`, invoke `run_once` at a weekday `07:00:05`, and verify one command and one automation event. Disable it, invoke the next due slot, and verify no new command.

- [ ] **Step 4: Return evidence**

Return migration result, test counts, command/event evidence, commits, and any production deployment prerequisite.
