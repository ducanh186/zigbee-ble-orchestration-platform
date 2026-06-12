# Shared Foundation and Integration Design

## Status

Approved design for implementation from `main` commit `4f6e2d9`.

This document coordinates three product branches:

- `feat/65-cloud-schedule-trigger-type`
- `feat/107-environment-sensor-automation-ui`
- `feat/66-mobile-scene-picker-schedule-template`

The implementation must preserve existing motion and switch automation behavior.

## Why a Shared Foundation Is Required

The three features are logically separate, but their current implementation points overlap:

- Environment thresholds and schedules both extend the automation trigger model.
- Environment conditions and schedule templates both extend the New Rule modal.
- Cloud schedule fields and environment threshold validation both touch automation schemas.

Starting three agents directly from unchanged `main` would create conflicts in the same
large Flutter modal and Cloud schema files. A small foundation commit must establish
extension points before parallel work starts.

## Branch and PR Strategy

1. Create `feat/65-cloud-schedule-trigger-type` from latest `main`.
2. Parent agent adds and verifies the shared foundation commit on that branch.
3. Create branches `feat/107-environment-sensor-automation-ui` and
   `feat/66-mobile-scene-picker-schedule-template` from the foundation commit.
4. Dispatch three agents in separate worktrees.
5. Initially open PR 65 against `main`.
6. Initially open PR 107 and PR 66 against `feat/65-cloud-schedule-trigger-type`.
7. After PR 65 merges, rebase or retarget PR 107 and PR 66 to `main`.

There is no fourth foundation PR.

## Foundation Scope

### Mobile automation model

Replace assumptions that every trigger is a device event with a typed trigger shape that
can represent:

- Existing motion or switch event.
- Environment sensor threshold.
- Schedule cron trigger.

Replace assumptions that every action is a direct device command with a typed action shape
that can represent:

- Existing direct light command.
- Light-only scene activation.

Wire values remain backward-compatible for existing rules.

### Mobile New Rule modal

Split the current large modal into independently owned sections:

- Shared form shell, validation summary, sticky footer, and save orchestration.
- Existing event device picker.
- Environment condition editor.
- Schedule picker.
- Direct light target picker.
- Light-scene picker.

The shared shell owns only composition and final draft submission. Feature-specific
validation and serialization live with the feature section.

### Cloud execution boundary

Extract direct light command creation and MQTT publication into a reusable service. Both
the REST command endpoint and schedule worker call this service.

The service must:

- Validate the target device and authorization context.
- Translate the friendly command to Gateway wire format.
- Create the `commands` row before publishing MQTT.
- Publish through the existing MQTT command method.
- Return the created command row or a structured failure.

### Cloud automation schema boundary

Use explicit discriminated trigger and action validation while preserving JSON storage:

- Event trigger.
- Sensor threshold trigger.
- Schedule trigger.
- Direct light action.
- Light-scene action.

Existing API payloads remain accepted.

## Ownership Boundaries for Parallel Agents

### Agent 1: Environment, provisioning, i18n

Owns:

- Environment MQTT validation and partial-state merge.
- Environment widgets and role visibility.
- Sensor threshold trigger UI and serialization.
- Gateway status API correction and Mobile mapping.
- Provisioning install-code regression audit.
- App-wide English/Vietnamese text audit.
- Environment and provisioning handoff documentation.

Must not implement cron scheduling or scene selection.

### Agent 2: Cloud schedule worker

Owns:

- Alembic setup and schedule migration.
- Schedule schema validation.
- Cron worker and lifecycle wiring.
- Reusable command execution path.
- Schedule execution audit events.
- Cloud schedule tests and automation contract update.

Must not modify Environment UI, i18n resources, or scene picker UI.

### Agent 3: Mobile schedule and light scenes

Owns:

- Schedule templates and cron picker.
- Light-only scene model, repository, API client, and UI.
- Empty scene behavior and direct-device fallback.
- Mobile schedule and scene tests.
- Cloud/Gateway scene handoff modules or documents that do not overlap Agent 2 files.

Must not implement the cron worker or Environment condition editor.

## Integration Rules

- Agents must not edit files outside their assigned scope without reporting the need first.
- Shared-file integration is performed by the parent agent after all agents return.
- The parent agent reviews every diff, resolves integration points, and runs the full suite.
- Existing untracked files in the original worktree are never copied, deleted, or committed.
- `dht11_environment_sensor_local_handoff (1).md` remains untracked and is added to the
  local repository exclude file, not the shared project `.gitignore`.

## Release Order

1. Merge and deploy Cloud schedule and shared contracts.
2. Merge Environment and Mobile schedule/scene PRs after their Cloud dependencies exist.
3. Build the Android release with the production API base URL.
4. Smoke-test Cloud APIs and Mobile critical flows.
5. Create GitHub release `v1.2.3` with a short summary covering all merged PRs.

The release notes must identify Gateway-only limitations:

- Environment telemetry requires Gateway implementation of the agreed MQTT contract.
- Scene execution requires Gateway Groups/Scenes support.

## Integration Acceptance

- All three feature branches originate from the same verified foundation commit.
- Agent-owned files do not overlap except through parent-controlled integration.
- Existing motion and switch rule tests still pass.
- Cloud tests pass.
- `flutter analyze` passes.
- `flutter test` passes.
- Android release build succeeds.
- Cloud deployment smoke tests pass before `v1.2.3` is published.
