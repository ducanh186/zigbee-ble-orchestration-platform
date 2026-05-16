# Automation E2E Plan

## Scope

This document is the Phase 0 skeleton for SCRUM-51. It defines the shared acceptance matrix and the fill-in order for the automation chain without forcing unfinished tickets to land partial test code.

The current API surface in this repo is `POST|GET|PUT|DELETE /api/automations`, not `/api/automation/rules`. All downstream work should extend that existing surface unless the contract explicitly changes.

## Current Status

- Phase 0 provides placeholders only.
- `cloud/tests/test_automation_e2e.py` is intentionally skip-only until the dependent tickets land.
- Manual demo evidence will be attached later in `docs/automation-e2e-report-YYYYMMDD.md`.

## Shared Rules

- Keep test IDs stable: `C*` for cloud API, `G*` for gateway harness, `E*` for end-to-end, `M*` for manual mobile evidence.
- Extend the existing MQTT contract and retained desired topic tree; do not invent a second automation transport.
- Use the current gateway source path `gateway/Z3GatewayHost/` in all new notes, scripts, and evidence.
- Add real assertions incrementally in the same skeleton file instead of spawning separate one-off automation test files.

## Fill Order

| Order | Ticket | Expected contribution |
| --- | --- | --- |
| 1 | SCRUM-44 | Freeze the automation contract and finalise expected request/response fields. |
| 2 | SCRUM-45 | Implement `C2`, `C3`, and stale-version behaviour for `C8`. |
| 3 | SCRUM-46 | Implement `C6` and `C7` against the retained MQTT desired topic. |
| 4 | SCRUM-47 | Implement `G1`, `G2`, `G3` and the gateway harness entrypoint. |
| 5 | SCRUM-48 | Implement `G4`, `G5`, `E1`, `E2`, `E3`, `E5`. |
| 6 | SCRUM-49 | Implement `G6`, `G7`, `E6` and event-log assertions. |
| 7 | SCRUM-51 | Wire the full suite together, add demo evidence, and remove remaining skips. |

## Acceptance Matrix

### Cloud API

| ID | Placeholder | Owner ticket | Status |
| --- | --- | --- | --- |
| C1 | Create automation rule returns `201` and `version = 1` | SCRUM-44/51 | Skeleton |
| C2 | Update automation rule bumps version | SCRUM-45 | Skeleton |
| C3 | Delete automation rule removes it from API reads | SCRUM-45 | Skeleton |
| C4 | Missing trigger is rejected | SCRUM-44 | Skeleton |
| C5 | Unsupported action type is rejected | SCRUM-44 | Skeleton |
| C6 | Create publishes retained `desired/automation/{id}` | SCRUM-46 | Skeleton |
| C7 | Delete publishes retained tombstone | SCRUM-46 | Skeleton |
| C8 | Concurrent update follows optimistic concurrency contract | SCRUM-44/45 | Skeleton |

### Gateway harness

| ID | Placeholder | Owner ticket | Status |
| --- | --- | --- | --- |
| G1 | Desired rule envelope is parsed into gateway state | SCRUM-47 | Skeleton |
| G2 | Malformed envelope does not mutate state | SCRUM-47 | Skeleton |
| G3 | Repeated rule id replaces prior state | SCRUM-47 | Skeleton |
| G4 | Motion trigger dispatches configured light action | SCRUM-48 | Skeleton |
| G5 | Non-matching motion trigger does nothing | SCRUM-48 | Skeleton |
| G6 | Successful execution publishes automation event | SCRUM-49 | Skeleton |
| G7 | Offline target publishes failed automation event | SCRUM-49 | Skeleton |

### End-to-end

| ID | Placeholder | Owner ticket | Status |
| --- | --- | --- | --- |
| E1 | Create rule then simulate motion turns light on | SCRUM-48/51 | Skeleton |
| E2 | Update rule then simulate motion turns light off | SCRUM-48/51 | Skeleton |
| E3 | Delete rule then motion produces no action | SCRUM-48/51 | Skeleton |
| E4 | Gateway executes cached rule while cloud is down | SCRUM-51 | Skeleton |
| E5 | Gateway restart restores retained rules | SCRUM-48/51 | Skeleton |
| E6 | Cloud event log returns execution rows | SCRUM-49/51 | Skeleton |

### Manual mobile evidence

| ID | Placeholder | Owner ticket | Status |
| --- | --- | --- | --- |
| M1 | Create rule from mobile automation flow | SCRUM-51 | Skeleton |
| M2 | Trigger event appears in notification center | SCRUM-24/51 | Skeleton |
| M3 | Edit rule action from mobile and verify new behaviour | SCRUM-51 | Skeleton |
| M4 | Delete rule from mobile and verify no follow-up action | SCRUM-51 | Skeleton |
| M5 | Network loss shows friendly error and no crash | SCRUM-30/51 | Skeleton |
