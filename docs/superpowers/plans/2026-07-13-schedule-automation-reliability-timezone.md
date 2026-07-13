# Schedule Automation Reliability + Timezone Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make cloud schedule automations run reliably, show timestamps in local time (GMT+7), support scheduled `toggle`, and stop `scene_activate` schedules from silently failing.

**Architecture:** All four fixes are cloud-only (`cloud/app`). Fix #1 hardens the async `ScheduleWorker` loop so a transient error can't kill it. Fix #2 converts naive-UTC datetimes to `Asia/Ho_Chi_Minh` in one shared serializer. Fix #3 resolves `toggle` to on/off from the latest `DeviceState`, and rejects `scene_activate` at creation until the (separate) Scenes project is built.

**Tech Stack:** Python 3.12, FastAPI, SQLAlchemy async, Pydantic v2, pytest / pytest-asyncio, croniter.

## Global Constraints

- Commits are solo-authored by `chuphu2004 <chuphu2004@gmail.com>`. Do **NOT** add a `Co-Authored-By` trailer (repo rule in `CLAUDE.md`).
- Work on branch `fix/schedule-automation-reliability-timezone` (already created; the design spec is committed there as `13b2eb4`).
- Run all tests from the repo root with `.venv/bin/python -m pytest`.
- Display timezone is hard-coded to `Asia/Ho_Chi_Minh` (single-site deployment) — this is intentional, not a TODO.
- Do **NOT** touch the worker's cron/timezone matching logic, `croniter`, or the minute-alignment sleep — those are already correct.
- Do **NOT** implement schedule "catch-up" for minutes missed while the worker was down.
- The Scenes subsystem is out of scope (separate project); this plan only rejects `scene_activate` at creation.

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `cloud/app/schedule_worker.py` | Async minute loop that fires due schedule rules | Add logging + crash protection |
| `cloud/app/schemas.py` | Pydantic response models + `_fmt_ts` display formatter | Convert naive-UTC → GMT+7 in `_fmt_ts` |
| `cloud/app/automation_execution.py` | Executes a schedule rule's actions | Resolve `toggle` to on/off from `DeviceState` |
| `cloud/app/routers/automations.py` | Automation CRUD + `_validate_rule_template` | Reject `scene_activate` at creation |
| `cloud/tests/test_schedule_worker.py` | Worker unit tests | New crash-survival test |
| `cloud/tests/test_schemas.py` | Schema/serializer tests | New `_fmt_ts` tz test |
| `cloud/tests/test_schedule_execution.py` | Executor tests | New `toggle` tests |
| `cloud/tests/test_automations.py` | Automation endpoint tests | Scene action now rejected |

---

### Task 1: Crash-proof the schedule worker (Fix #1)

**Files:**
- Modify: `cloud/app/schedule_worker.py`
- Test: `cloud/tests/test_schedule_worker.py`

**Interfaces:**
- Consumes: `ScheduleWorker(session_factory, *, executor=...)`, `worker.run_once(now)` (existing).
- Produces: unchanged public API; adds module-level `logger = logging.getLogger(__name__)`. `run_once` now never propagates a per-rule executor exception; `run_forever` never exits on a `run_once` exception.

- [ ] **Step 1: Write the failing test**

Add to `cloud/tests/test_schedule_worker.py`:

```python
@pytest.mark.asyncio
async def test_worker_survives_executor_error_and_runs_other_rules(
    db_session_factory,
):
    from cloud.app.schedule_worker import ScheduleWorker

    async with db_session_factory() as session:
        for rid in ("bad-rule", "good-rule"):
            session.add(
                Automation(
                    id=rid,
                    name=rid,
                    enabled=True,
                    tenant_id="hust",
                    site_id="lab01",
                    gateway_id="gw-ubuntu-01",
                    trigger_type="schedule",
                    schedule_cron="0 7 * * *",
                    trigger={"type": "schedule"},
                    actions=[],
                    sync_status="synced",
                    last_run_status="never_run",
                )
            )
        await session.commit()

    calls: list[str] = []

    async def flaky_executor(db, rule, *, scheduled_for):
        calls.append(rule.id)
        if rule.id == "bad-rule":
            raise RuntimeError("boom")

    worker = ScheduleWorker(db_session_factory, executor=flaky_executor)
    now = datetime(2026, 6, 15, 7, 0, 5, tzinfo=ZoneInfo("Asia/Ho_Chi_Minh"))

    # Must NOT raise, even though one rule's executor raises.
    await worker.run_once(now)

    assert set(calls) == {"bad-rule", "good-rule"}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest cloud/tests/test_schedule_worker.py::test_worker_survives_executor_error_and_runs_other_rules -v`
Expected: FAIL — `RuntimeError: boom` propagates out of `run_once` (no try/except yet).

- [ ] **Step 3: Implement crash protection**

In `cloud/app/schedule_worker.py`, add the `logging` import and module logger:

```python
import asyncio
import logging
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from croniter import croniter
from sqlalchemy import select

from cloud.app.automation_execution import execute_automation_rule
from cloud.app.models import Automation

logger = logging.getLogger(__name__)

SCHEDULE_TIMEZONE = ZoneInfo("Asia/Ho_Chi_Minh")
```

Replace the per-rule loop in `run_once` (the `for rule in rules:` block) with a version that isolates each rule:

```python
            for rule in rules:
                key = (rule.id, slot)
                if key in self._last_slots:
                    continue
                if not (
                    rule.schedule_cron
                    and is_schedule_due(rule.schedule_cron, slot)
                ):
                    continue
                try:
                    await self._executor(
                        db,
                        rule,
                        scheduled_for=slot.replace(tzinfo=None),
                    )
                    self._last_slots.add(key)
                except Exception:
                    # One bad rule must not sink the batch or bubble out of
                    # run_once. Key is NOT added, so it retries next tick.
                    logger.exception(
                        "schedule rule %s failed to execute", rule.id
                    )
```

Replace `run_forever` with a loop that survives a failing `run_once` and logs start/stop (mirrors `command_timeout.py`):

```python
    async def run_forever(self, stop_event: asyncio.Event) -> None:
        logger.info("Schedule worker started (tz=%s)", self.timezone)
        while not stop_event.is_set():
            try:
                await self.run_once()
            except Exception:
                logger.exception("schedule run_once failed")
            now = datetime.now(self.timezone)
            delay = 60 - now.second - now.microsecond / 1_000_000
            try:
                await asyncio.wait_for(stop_event.wait(), timeout=delay)
            except asyncio.TimeoutError:
                pass
        logger.info("Schedule worker stopped")
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `.venv/bin/python -m pytest cloud/tests/test_schedule_worker.py -v`
Expected: PASS — all three tests (two existing + the new one).

- [ ] **Step 5: Commit**

```bash
git add cloud/app/schedule_worker.py cloud/tests/test_schedule_worker.py
git commit -m "fix(cloud): keep schedule worker alive across run_once errors"
```

---

### Task 2: Display timestamps in Asia/Ho_Chi_Minh (Fix #2)

**Files:**
- Modify: `cloud/app/schemas.py:1-27`
- Test: `cloud/tests/test_schemas.py`

**Interfaces:**
- Consumes: nothing new.
- Produces: `_fmt_ts(value: datetime | None) -> str | None` now converts a naive value (assumed UTC) to `Asia/Ho_Chi_Minh` before formatting. Every serializer that already calls `_fmt_ts` (device/command/gateway/automation/automation-event timestamps) inherits the fix. `.isoformat()` serializers (auth token expiries) are deliberately unchanged.

- [ ] **Step 1: Write the failing test**

Add to `cloud/tests/test_schemas.py` (top-level, module scope):

```python
def test_fmt_ts_converts_naive_utc_to_local():
    from datetime import datetime

    from cloud.app.schemas import _fmt_ts

    # 18:55 UTC on 2026-07-12 == 01:55 (+07) on 2026-07-13.
    assert _fmt_ts(datetime(2026, 7, 12, 18, 55)) == "01:55 07/13/2026"


def test_fmt_ts_none_passthrough():
    from cloud.app.schemas import _fmt_ts

    assert _fmt_ts(None) is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest cloud/tests/test_schemas.py::test_fmt_ts_converts_naive_utc_to_local -v`
Expected: FAIL — current `_fmt_ts` returns `"18:55 07/12/2026"` (no tz conversion).

- [ ] **Step 3: Implement the conversion**

In `cloud/app/schemas.py`, update the imports (line 4) and add the display zone + new `_fmt_ts`:

```python
from datetime import UTC, datetime
from enum import Enum
from typing import Annotated, Any, Literal
from zoneinfo import ZoneInfo
```

```python
TS_DISPLAY_FORMAT = "%H:%M %m/%d/%Y"
DISPLAY_TIMEZONE = ZoneInfo("Asia/Ho_Chi_Minh")


def _fmt_ts(value: datetime | None) -> str | None:
    if value is None:
        return None
    aware = value.replace(tzinfo=UTC) if value.tzinfo is None else value
    return aware.astimezone(DISPLAY_TIMEZONE).strftime(TS_DISPLAY_FORMAT)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `.venv/bin/python -m pytest cloud/tests/test_schemas.py -v`
Expected: PASS — the two new tests pass and no existing schema test regresses.

- [ ] **Step 5: Commit**

```bash
git add cloud/app/schemas.py cloud/tests/test_schemas.py
git commit -m "fix(cloud): render API timestamps in Asia/Ho_Chi_Minh local time"
```

---

### Task 3: Cloud-side `toggle` for scheduled actions (Fix #3a)

**Files:**
- Modify: `cloud/app/automation_execution.py`
- Test: `cloud/tests/test_schedule_execution.py`

**Interfaces:**
- Consumes: `execute_device_command(...)`, `DeviceState` model (`device_id`, `state` JSON, `reported_at`).
- Produces: `execute_automation_rule` accepts action `command ∈ {on, off, toggle}`. `toggle` is resolved to the opposite of the light's latest `DeviceState.state["power"]`; if no usable power state exists, that action fails with reason `toggle requires known device power state` (an `automation_failed` event, not a crash).

- [ ] **Step 1: Write the failing tests**

Add to `cloud/tests/test_schedule_execution.py` (imports at top already include `Automation, AutomationEvent, Device, Home, Room`; add `DeviceState`):

```python
@pytest.mark.asyncio
async def test_scheduled_toggle_sends_opposite_of_current_power(
    db_session_factory,
    fake_mqtt,
):
    from cloud.app.automation_execution import execute_automation_rule
    from cloud.app.models import DeviceState

    async with db_session_factory() as session:
        session.add(Home(id="home-1", name="Test Home"))
        session.add(Room(id="room-1", home_id="home-1", name="Living"))
        session.add(
            Device(
                id="light-01",
                device_type="light",
                room_id="room-1",
                name="Main Light",
                is_online=True,
            )
        )
        session.add(
            DeviceState(
                device_id="light-01",
                state={"power": "off"},
                reported_at=datetime(2026, 6, 15, 6, 0),
            )
        )
        rule = Automation(
            id="sch-toggle",
            name="Toggle light",
            enabled=True,
            tenant_id="hust",
            site_id="lab01",
            gateway_id="gw-ubuntu-01",
            trigger_type="schedule",
            schedule_cron="0 7 * * *",
            trigger={"type": "schedule"},
            actions=[
                {
                    "type": "device_command",
                    "device_id": "light-01",
                    "device_type": "light",
                    "command": "toggle",
                }
            ],
            sync_status="synced",
            last_run_status="never_run",
        )
        session.add(rule)
        await session.commit()

        await execute_automation_rule(
            session, rule, scheduled_for=datetime(2026, 6, 15, 7, 0)
        )

    assert fake_mqtt.published[-1]["target"]["command"] == "on"


@pytest.mark.asyncio
async def test_scheduled_toggle_without_state_fails_cleanly(
    db_session_factory,
    fake_mqtt,
):
    from cloud.app.automation_execution import execute_automation_rule

    async with db_session_factory() as session:
        session.add(Home(id="home-2", name="Test Home 2"))
        session.add(Room(id="room-2", home_id="home-2", name="Living"))
        session.add(
            Device(
                id="light-02",
                device_type="light",
                room_id="room-2",
                name="Stateless Light",
                is_online=True,
            )
        )
        rule = Automation(
            id="sch-toggle-nostate",
            name="Toggle no state",
            enabled=True,
            tenant_id="hust",
            site_id="lab01",
            gateway_id="gw-ubuntu-01",
            trigger_type="schedule",
            schedule_cron="0 7 * * *",
            trigger={"type": "schedule"},
            actions=[
                {
                    "type": "device_command",
                    "device_id": "light-02",
                    "device_type": "light",
                    "command": "toggle",
                }
            ],
            sync_status="synced",
            last_run_status="never_run",
        )
        session.add(rule)
        await session.commit()

        events = await execute_automation_rule(
            session, rule, scheduled_for=datetime(2026, 6, 15, 7, 0)
        )

    assert events[0].event_type == "automation_failed"
    assert events[0].reason == "toggle requires known device power state"
    assert fake_mqtt.published == []
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `.venv/bin/python -m pytest cloud/tests/test_schedule_execution.py -k toggle -v`
Expected: FAIL — current executor rejects `toggle` with `scheduled actions support light on/off only`.

- [ ] **Step 3: Implement toggle resolution**

In `cloud/app/automation_execution.py`, update the imports:

```python
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.command_execution import (
    CommandExecutionError,
    execute_device_command,
)
from cloud.app.models import Automation, AutomationEvent, DeviceState
```

Add a helper above `execute_automation_rule`:

```python
async def _resolve_toggle(db: AsyncSession, device_id: str) -> str:
    row = (
        await db.execute(
            select(DeviceState.state)
            .where(DeviceState.device_id == device_id)
            .order_by(DeviceState.reported_at.desc())
            .limit(1)
        )
    ).first()
    power = (row[0] or {}).get("power") if row else None
    if power not in {"on", "off"}:
        raise CommandExecutionError(
            422, "toggle requires known device power state"
        )
    return "off" if power == "on" else "on"
```

Replace the command check inside the action loop (the `command = action.get("command")` block):

```python
            command = action.get("command")
            if command not in {"on", "off", "toggle"}:
                raise CommandExecutionError(
                    422,
                    "scheduled actions support light on/off/toggle only",
                )
            if command == "toggle":
                command = await _resolve_toggle(db, action["device_id"])
            created = await execute_device_command(
                db,
                device_id=action["device_id"],
                op="set",
                target={"power": command},
                timeout_ms=5000,
                current_user=None,
            )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `.venv/bin/python -m pytest cloud/tests/test_schedule_execution.py -v`
Expected: PASS — new toggle tests pass, existing on/off execution test still passes.

- [ ] **Step 5: Commit**

```bash
git add cloud/app/automation_execution.py cloud/tests/test_schedule_execution.py
git commit -m "feat(cloud): resolve scheduled light toggle from latest device state"
```

---

### Task 4: Reject `scene_activate` schedules at creation (Fix #3b)

**Files:**
- Modify: `cloud/app/routers/automations.py:189-197`
- Test: `cloud/tests/test_automations.py:181-203`

**Interfaces:**
- Consumes: existing `_validate_rule_template(db, trigger, actions, current_user)`.
- Produces: any automation action with `type == "scene_activate"` now returns HTTP 422 `scheduled scene actions are not yet supported`. (Schema `SceneActivateAction` is left intact so the future Scenes project can re-enable it by removing this guard.)

- [ ] **Step 1: Update the endpoint test to expect rejection**

In `cloud/tests/test_automations.py`, replace the body of `test_create_schedule_rule_accepts_scene_action` and rename it:

```python
@pytest.mark.asyncio
async def test_create_schedule_rule_rejects_scene_action(
    client, db_session_factory, fake_mqtt
):
    headers = await _parent_headers(client, db_session_factory)
    rule = _schedule_on_rule()
    rule["actions"] = [
        {
            "type": "scene_activate",
            "group_id": "group-lab",
            "scene_id": "scene-all-off",
        }
    ]

    response = await client.post(
        "/api/automations",
        json=rule,
        headers=headers,
    )

    assert response.status_code == 422, response.text
    assert response.json()["detail"] == (
        "scheduled scene actions are not yet supported"
    )
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.venv/bin/python -m pytest cloud/tests/test_automations.py::test_create_schedule_rule_rejects_scene_action -v`
Expected: FAIL — creation currently returns 201 (scene action accepted).

- [ ] **Step 3: Implement the rejection**

In `cloud/app/routers/automations.py`, replace the `scene_activate` block inside `_validate_rule_template`:

```python
        if action_type == "scene_activate":
            raise HTTPException(
                status_code=422,
                detail="scheduled scene actions are not yet supported",
            )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `.venv/bin/python -m pytest cloud/tests/test_automations.py -v`
Expected: PASS — the renamed test passes; no other automation endpoint test regresses.

- [ ] **Step 5: Commit**

```bash
git add cloud/app/routers/automations.py cloud/tests/test_automations.py
git commit -m "fix(cloud): reject scheduled scene actions until scenes ship"
```

---

### Task 5: Full suite + deploy + live verification

**Files:** none (operational).

- [ ] **Step 1: Run the whole cloud suite**

Run: `.venv/bin/python -m pytest cloud/tests -q`
Expected: PASS (no regressions across all cloud tests).

- [ ] **Step 2: Redeploy to EC2 `sb-cloud-api`**

Per the standing EC2-sync rule: rebuild + restart the `sb-cloud-api` container (Docker, build context `deploy/cloud`, rebuild + `docker-compose up`). Do **NOT** touch `deploy/cloud/.env`.

- [ ] **Step 3: Confirm the worker is alive**

Run: `docker logs sb-cloud-api | grep -i "Schedule worker started"`
Expected: the start line appears (Fix #1 logging), confirming the worker is running.

- [ ] **Step 4: Live verify a schedule fires + local time shows**

Create a schedule ~2 min ahead for a light `on`. At the scheduled minute, confirm via the API an `automation_executed` event appears and the light turns on. Confirm `GET /api/devices/` `last_seen_at` now reads local GMT+7 (e.g. `01:5x 07/13/2026`, not `18:5x 07/12`).

- [ ] **Step 5: Clean up diagnosis leftovers**

Delete the two probe rules `sche` (`55 * * * *`) and `sche dule 2` (`57 2 * * *`) and turn light `004F` off if still on.

---

## Self-Review

**Spec coverage:**
- Fix #1 (worker crash-proofing) → Task 1. ✓
- Fix #2 (GMT+7 display via `_fmt_ts`) → Task 2. ✓
- Fix #3a (cloud toggle) → Task 3. ✓
- Fix #3b (reject scene_activate) → Task 4. ✓
- Testing + rollout + live verify + cleanup → Task 5. ✓
- Non-goals (no catch-up, no Scenes subsystem, cron/tz untouched, auth isoformat untouched) → respected; called out in Global Constraints. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code and exact commands. ✓

**Type consistency:** `_resolve_toggle(db, device_id) -> str` defined and used in Task 3; `_fmt_ts` signature matches the existing call sites; `DeviceState.state`/`reported_at` match the model; the rejection `detail` string is identical in the Task 4 test and implementation. ✓
