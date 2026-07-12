# Schedule Automation Reliability + Timezone Display — Design

- **Date:** 2026-07-13
- **Branch:** `feat/107-environment-sensor-automation-ui`
- **Component:** `cloud/` (FastAPI schedule worker, schemas, automation executor)
- **Status:** Design — awaiting spec review

## 1. Problem statement

User report (VN): schedule automations "don't work". The gateway shows a time
~7 h behind the user's wall clock (GMT+7). Rules created in the mobile app show
`sync` status and look usable, but the light never turns on at the scheduled
time. The user suspected the clock skew was the cause.

## 2. Diagnostic evidence (live test against production EC2)

A controlled read-only reproduction was run against
`https://dashboard.iot-building.app` (same backend as `98.83.4.87:8000`) while
the user created two schedule rules from the mobile app:

| Local time | Rule (cron)        | Result |
|------------|--------------------|--------|
| 02:55      | `sche` (`55 * * * *`) | ❌ Did **not** fire — `events=0`, `last_run=never_run`, light off |
| 02:57      | `sche dule 2` (`57 2 * * *`) | ✅ **Fired** — `automation_executed`, light `004F` turned **ON**, `scheduled_for=2026-07-13T02:57:00` |

Key facts established:

- **Schedule execution fundamentally works.** The 02:57 rule fired at the
  correct **local** minute and turned on the light. So the worker timezone
  (`Asia/Ho_Chi_Minh`), the EC2 clock, `croniter.match`, and the mobile app's
  cron builder are all correct. The clock-skew theory is a **red herring** for
  execution.
- **Rules persist correctly.** Both rules reached the DB with
  `sync_status=synced` (schedule rules are cloud-only; `_syncs_to_gateway()`
  returns `False`, so `synced` just means "nothing to push to the gateway").
- The 02:55 rule was **missed** despite `croniter.match("55 * * * *", 02:55
  local) == True` (verified locally). Combined with the later 02:57 success,
  the most plausible explanation is that the worker task **died** before 02:55
  and the cloud process restarted before 02:57.
- Device/automation timestamps returned by the API (`last_seen_at`,
  `updated_at`, `occurred_at`, …) render as e.g. `18:55 07/12/2026` — that is
  UTC formatted **without timezone conversion** (= `01:55 07/13` local). This
  is exactly the "gateway time is wrong" symptom.

## 3. Root causes

| # | Root cause | Evidence | Confidence |
|---|------------|----------|------------|
| 1 | **Worker has no crash protection.** `ScheduleWorker.run_forever` calls `await self.run_once()` with **no `try/except`**. A single transient error (DB drop, query timeout) exits the `while` loop, the asyncio task completes, and **no schedule fires again until the cloud process restarts.** | `schedule_worker.py:67-75`; live 02:55 miss then 02:57 success | High — best explanation for "nothing runs for hours/days" |
| 2 | **Timestamps displayed as UTC.** All human-facing datetimes are stored naive-UTC and serialized via `_fmt_ts` = `value.strftime("%H:%M %m/%d/%Y")` with no tz conversion → shown ~7 h behind local. | `schemas.py:21-27` + live API | High — matches "wrong gateway time" |
| 3 | **Silent-fail trap for `toggle`/`scene_activate` schedule actions.** Creation validation accepts `command ∈ {on,off,toggle}` and `scene_activate`, but the runtime executor `execute_automation_rule` only handles light `on`/`off`; `toggle` and `scene_activate` always produce `automation_failed`. `PowerState` has no `toggle`; the gateway has no scene-recall path. | `routers/automations.py:189-207`, `automation_execution.py:27-34`, `schemas.py` `PowerState`(on/off only) | Medium — latent; not what this user hit (they used on/off) |

## 4. Already correct — non-goals

- Worker/cron timezone logic, EC2 clock, `croniter` matching — **correct**, do
  not touch.
- Mobile app cron construction (`schedule_trigger_section.dart` builds
  `${minute} ${hour} * * *` in local time) — **consistent** with the worker.
- Retroactive "catch-up" firing of schedules missed while the worker was down
  — **out of scope** (avoid double-fires / stale actions). Fix #1 only prevents
  the worker from dying; it does not replay missed slots.
- The **Scenes subsystem** (cloud `Scene` model + `/api/scenes` CRUD +
  scene-execution fan-out + mobile scene-management UI) — **out of scope**,
  decomposed into its own follow-up project. It does not exist today (see 5.3).
  This spec only rejects `scene_activate` at creation.

## 5. Design

### 5.1 Fix #1 — Make the schedule worker crash-proof

Mirror the proven pattern already in `command_timeout.py` (which wraps
`sweep_once` in `try/except` + `logger.exception` and keeps looping).

- Add `logger = logging.getLogger(__name__)` to `schedule_worker.py`.
- **`run_forever`:** wrap `await self.run_once()` in `try/except Exception` →
  `logger.exception("schedule run_once failed")` and continue the loop. The
  minute-alignment sleep stays outside the try so timing is preserved.
- **`run_once`:** wrap the **per-rule** execution (`is_schedule_due` check +
  `self._executor(...)`) in `try/except Exception` → log with the rule id and
  continue to the next rule, so one bad rule cannot sink the whole batch or
  bubble out of `run_once`. `_last_slots` is only updated on success so a
  failed minute can retry next tick.
- Add startup/stop `logger.info` lines (parity with the timeout worker) to make
  "is the worker alive?" observable in `docker logs sb-cloud-api`.

### 5.2 Fix #2 — Display timestamps in Asia/Ho_Chi_Minh (server-side convert)

Chosen approach (per user): convert on the server; keep the existing string
shape so the mobile app needs no change.

- In `schemas.py` add `DISPLAY_TIMEZONE = ZoneInfo("Asia/Ho_Chi_Minh")`.
- Change `_fmt_ts` to treat a naive value as UTC, convert to
  `DISPLAY_TIMEZONE`, then `strftime(TS_DISPLAY_FORMAT)`:

  ```python
  def _fmt_ts(value: datetime | None) -> str | None:
      if value is None:
          return None
      aware = value.replace(tzinfo=UTC) if value.tzinfo is None else value
      return aware.astimezone(DISPLAY_TIMEZONE).strftime(TS_DISPLAY_FORMAT)
  ```

- This single change fixes every `_fmt_ts` serializer: device
  `reported_at/last_seen_at/created_at/updated_at`, command timestamps, gateway
  `occurred_at`, automation `created_at/updated_at`, and automation-event
  `occurred_at`.
- **Leave `.isoformat()` serializers as-is** (auth `expires_at` /
  `refresh_expires_at`): those feed the app's token-expiry logic, which works
  in UTC. Out of scope to change.
- Trade-off accepted: the display zone is hard-coded to GMT+7 (single-site
  deployment). A future multi-tz design would return ISO-8601 with offset and
  localize per client; noted as a follow-up, not done here.

### 5.3 Fix #3 — Remove the `toggle` / `scene_activate` silent-fail trap

Goal: a scheduled action that is accepted at creation must actually run, or be
rejected clearly at creation. No silent runtime failures.

- **`toggle` (recommended: make it work, cloud-only).** In
  `execute_automation_rule`, handle `command == "toggle"` by reading the
  target light's last known power from `Device.state` and issuing the opposite
  `on`/`off` via `execute_device_command`. No firmware or enum change needed.
  If the device has no known state, fail that action with a clear reason
  (`toggle requires known device state`).
- **`scene_activate` (decided: reject at creation).** The Scenes subsystem
  does **not exist** on the cloud yet — no `Scene` model/table/migration, no
  `/api/scenes` router (live `GET /api/scenes` → 404), and the mobile app maps
  that 404 to `SceneAvailability.unavailable`, so the app already hides scene
  targets and cannot create a `scene_activate` schedule. Therefore reject
  `scene_activate` in `_validate_rule_template` with a clear 422
  (`scheduled scene actions are not yet supported`). This turns a silent
  runtime failure into an explicit creation error and matches the app's current
  reality.

**Scenes is a separate follow-up project (not this spec).** Per the user's
decision, full scene execution is decomposed into its own brainstorm → spec →
plan. Note the target architecture: a Scene is a cloud-side collection of
per-light `on`/`off` states (see
`2026-06-13-mobile-light-scenes-schedule-design.md`), so execution is a **cloud
fan-out** of `execute_device_command` over the scene's member lights — **no**
gateway ZCL RecallScene needed. That future project must build: `Scene`/member
model + migration, `/api/scenes` CRUD + visibility, a scene-execution branch in
`execute_automation_rule`, and scene-management UI in the mobile app.

## 6. Testing

Extend existing suites (same `db_session_factory` / `ScheduleWorker(...,
executor=...)` harness):

- `test_schedule_worker.py`: new test — an executor that raises for one rule
  does **not** propagate out of `run_once`, is logged, and a second due rule in
  the same tick still fires. (Guards Fix #1.)
- `test_schemas.py`: `_fmt_ts` converts a known naive-UTC datetime to the
  expected GMT+7 wall-clock string (e.g. `18:55 07/12` UTC → `01:55 07/13`).
  (Guards Fix #2.)
- `test_schedule_execution.py` / `test_automations.py`: scheduled `toggle`
  flips based on stored power; scheduled `scene_activate` is rejected at
  creation with 422. (Guards Fix #3.)

## 7. Rollout & verification

1. Land cloud changes on the feature branch; run `cloud/tests` green locally.
2. Redeploy to EC2 `sb-cloud-api` (Docker, build context `deploy/cloud`,
   rebuild + `docker-compose up`; never touch `deploy/cloud/.env`) per the
   standing EC2-sync rule.
3. Confirm the worker is alive: `docker logs sb-cloud-api` shows the schedule
   worker start line.
4. Live verify: create a schedule ~2 min ahead for a light `on`; confirm at the
   scheduled minute an `automation_executed` event appears and the light turns
   on. Confirm API timestamps now read local (GMT+7).
5. Clean up the two leftover test rules (`sche`, `sche dule 2`) and the
   `004F`-on state from diagnosis.

## 8. Risks

- Hard-coded GMT+7 display is wrong if the deployment ever spans timezones
  (accepted; documented).
- `_fmt_ts` change alters every displayed timestamp string; low risk since the
  format shape is unchanged, but screenshots/tests asserting old UTC strings
  must be updated.
- Cloud-side `toggle` depends on `Device.state.power` being reasonably fresh;
  stale state could toggle "wrong", hence the explicit no-state failure path.
