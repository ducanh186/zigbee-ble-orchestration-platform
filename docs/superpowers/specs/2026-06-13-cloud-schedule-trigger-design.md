# Cloud Schedule Trigger Design

## Branch

`feat/65-cloud-schedule-trigger-type`

## Goal

Allow an active automation to execute direct light actions from a five-field cron
expression without requiring a device event.

Example:

```text
Every weekday at 07:00 -> turn on Light A
```

## Database Migration

The repository currently has no Alembic framework. This branch introduces Alembic and one
additive migration for existing deployments.

Add to `automations`:

- `trigger_type`: enum `event | schedule`, non-null, default `event`.
- `schedule_cron`: text, nullable.

Migration order:

1. Create the PostgreSQL enum if absent.
2. Add `trigger_type` with server default `event`.
3. Backfill all existing rows as `event`.
4. Add nullable `schedule_cron`.
5. Keep the `event` default for backward compatibility.

Deployment must run `alembic upgrade head` before starting the new Cloud process.
The migration must preserve all existing automation rows and JSON payloads.

## API Contract

### Existing event rule

```json
{
  "name": "Motion turns on light",
  "enabled": true,
  "trigger_type": "event",
  "schedule_cron": null,
  "trigger": {
    "device_id": "motion-01",
    "device_type": "motion",
    "event": "occupancy_changed"
  },
  "actions": [
    {
      "device_id": "light-01",
      "device_type": "light",
      "command": "on"
    }
  ]
}
```

### Schedule rule

```json
{
  "name": "Weekday morning light",
  "enabled": true,
  "trigger_type": "schedule",
  "schedule_cron": "0 7 * * 1-5",
  "trigger": {
    "type": "schedule"
  },
  "actions": [
    {
      "device_id": "light-01",
      "device_type": "light",
      "command": "on"
    }
  ]
}
```

Validation:

- `event` requires an existing event trigger and requires `schedule_cron = null`.
- `schedule` requires `trigger.type = schedule` and a valid five-field cron string.
- Six-field cron strings with seconds are rejected.
- A schedule action must target a manageable light or a validated light-only scene.
- Invalid requests return HTTP 422.

## Cron Semantics

Library: `croniter`.

Timezone: `Asia/Ho_Chi_Minh`.

Presets map to:

- Every weekday 07:00: `0 7 * * 1-5`.
- Every Sunday 22:00: `0 22 * * 0`.
- Every six hours: `0 */6 * * *`.

The stored cron string does not include timezone. The Cloud scheduler configuration owns
the timezone for this release.

## Worker

Use an asyncio worker following the existing timeout worker and offline reaper lifecycle.

Behavior:

1. Wake on the next minute boundary.
2. Query enabled `schedule` rules.
3. Evaluate each cron expression against the current local scheduler minute.
4. Execute every action through the shared command dispatch service.
5. Insert an `automation_events` row for success or failure.
6. Update `last_run_status` and `last_error`.

The current deployment must run exactly one scheduler-enabled Cloud process. Add a
configuration switch so additional API replicas can disable the worker.

Within the active process, keep a minute execution key:

```text
automation_id + scheduled minute + action index
```

This prevents duplicate execution during repeated loop ticks in the same minute.

## Execution Path

The worker must reuse the same command behavior as REST:

```text
Schedule worker
-> shared command dispatch service
-> command row
-> MQTT commands/{command_id}/request
-> Gateway
-> Zigbee light command
-> command reply
```

Do not call the HTTP command endpoint internally.

For each schedule run, insert an `automation_events` row with:

```json
{
  "event_type": "automation_executed",
  "status": "executed",
  "payload": {
    "trigger_type": "schedule",
    "scheduled_for": "2026-06-15T07:00:00+07:00",
    "command_ids": ["..."]
  }
}
```

On partial action failure, record `failed`, preserve successful command IDs, and include a
non-sensitive reason.

## Gateway Interaction

Schedule evaluation stays in Cloud. Schedule rules are not synced as local event rules to
Gateway.

Gateway receives only normal command requests at execution time. This avoids teaching the
embedded Gateway cron syntax, timezone, or daylight-saving behavior.

Existing event rules continue to sync through `automations/{id}/desired`.

## Contract Documentation

Create `docs/AUTOMATION_CONTRACT.md` because latest `main` currently consolidates contracts
in `docs/CONTRACTS.md` and does not contain this requested file.

The new document must:

- State that it extends rather than replaces the frozen event contract.
- Document `trigger_type` and `schedule_cron`.
- Explain Cloud-owned schedule execution.
- Preserve all existing event trigger and action wire names.
- Cross-link from `docs/CONTRACTS.md`.

## Tests

- Migration upgrades an existing automation table without data loss.
- Existing event rule create/update/list behavior remains unchanged.
- Valid weekday cron is accepted.
- Invalid cron returns 422.
- Six-field cron returns 422.
- Disabled schedule is not executed.
- Due schedule executes at `07:00:0X`.
- Not-due schedule does not execute.
- Repeated worker ticks in one minute do not duplicate commands.
- Command row is created before MQTT publication.
- Success and failure write `automation_events`.
- Worker shuts down cleanly with the application lifespan.

Use a fixed injected clock in tests. Do not sleep until real wall-clock times.

## Acceptance

- A weekday 07:00 rule publishes its light command within the first worker tick after
  07:00.
- Disabling the rule prevents execution.
- Invalid cron is rejected with 422.
- Existing event automation behavior and tests remain green.
- Migration and rollback instructions are documented.
- Focused and full Cloud tests pass.
