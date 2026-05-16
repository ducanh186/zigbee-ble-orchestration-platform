# Sprint Execution Plan - Updated Two-Person Split

**Date**: 2026-05-16
**Owner (drafter)**: ducanh186 (leducanh180604@gmail.com)
**Status**: UPDATED after review on `origin/main@0bf4ba7`

## Goal

Finish the remaining sprint work without redoing merged tickets and without touching Gateway implementation files. The current working boundary is:

- Person A / collaborator owns backend and any Gateway implementation.
- Person B / ducanh186 owns mobile work and SCRUM-51 mobile/demo evidence.
- This Codex session must not modify `gateway/`.

## Current baseline

The original planning commit `2786fdc` was written against `main@5bc9eb1`. After fetching origin on 2026-05-16, `origin/main` is now `0bf4ba7`.

Merged after the original spec:

| Ticket | Merge evidence | Result |
|---|---|---|
| SCRUM-51 | PR #27, commit `9c4f16e` | E2E skeleton and `docs/automation-e2e-plan.md` are already on `main`. |
| SCRUM-45 | PR #28, commit `ae3ad00` | Cloud automation PUT/DELETE/versioning is already on `main`. |
| SCRUM-46 | PR #29, commit `0989d30` | Cloud MQTT publish for automation rules is already on `main`. |
| SCRUM-49 | PR #30, commit `2dc3769` | Cloud automation event logging is already on `main`. |

Branch naming rule from `README.md`:

```text
prefix/<jira-ticket-id>-<short-description>
```

Examples already used in this repo:

```text
feature/43-mobile-automation-rule-management
docs/43-automation-app-docs
```

Therefore this plan uses branch names such as `feature/20-mobile-auth-session`, not `feature/SCRUM-20-mobile-auth-session`.

## Tickets in scope for this plan

### Mobile - Person B

| Ticket | Summary | Branch | Status |
|---|---|---|---|
| SCRUM-20 | Mobile auth & session | `feature/20-mobile-auth-session` | To Do |
| SCRUM-29 | Mobile login/logout screen | `feature/29-mobile-login-logout-screen` | To Do; depends on SCRUM-20 |
| SCRUM-30 | Mobile error handling | `feature/30-mobile-error-handling` | To Do; can start after SCRUM-20 session contract |
| SCRUM-21 | Mobile real-time device state sync | `feature/21-mobile-realtime-device-sync` | To Do |
| SCRUM-23 | Mobile occupancy monitoring screen | `feature/23-mobile-occupancy-monitoring` | To Do |
| SCRUM-24 | Mobile notification center | `feature/24-mobile-notification-center` | To Do |
| SCRUM-25 | Mobile OTA progress screen | `feature/25-mobile-ota-progress` | To Do |
| SCRUM-50 | Mobile device reachable / cloud status indicators | `feature/50-mobile-device-status-indicators` | To Do |

### Docs / E2E evidence - Person B contribution only

| Ticket | Summary | Branch | Status |
|---|---|---|---|
| SCRUM-51 | Automation E2E suite and demo evidence | `feature/51-automation-e2e-tests` | Skeleton merged; Person B only owns mobile smoke evidence M1-M5. |

### External dependencies, not touched by this session

| Ticket | Summary | Branch | Status |
|---|---|---|---|
| SCRUM-44 | Automation contract specification | `docs/44-automation-contract-spec` | External/documentation dependency unless explicitly assigned later. |
| SCRUM-8 | Cloud OTA manager | `feature/8-cloud-ota-manager` | External/backend dependency unless explicitly assigned later. |
| SCRUM-47 | Gateway subscribe & apply automation ops | `feature/47-gateway-automation-subscribe` | Gateway-owned. Do not modify `gateway/`. |
| SCRUM-48 | Gateway motion-triggered automation | `feature/48-gateway-motion-automation` | Gateway-owned. Do not modify `gateway/`. |

## Revised phasing

### Phase 0 - Already complete on main

- SCRUM-51 skeleton is merged.
- SCRUM-45, SCRUM-46, and SCRUM-49 are merged.
- Do not create another skeleton PR.

### Phase 1 - Backend/Gateway continuation outside this session

- SCRUM-44 should freeze the contract if the team still needs a formal doc.
- SCRUM-47 and SCRUM-48 must be handled by the Gateway owner.
- This session tracks those as blockers only; it must not edit `gateway/`.

### Phase 2 - Mobile track, safe to continue now

Recommended order:

1. SCRUM-20 - establish mobile auth/session foundation.
2. SCRUM-29 - build login/logout UI on top of the session layer.
3. SCRUM-30 - add consistent mobile error handling.
4. SCRUM-21 - add real-time device state sync.
5. SCRUM-23 - build occupancy monitoring from synced state/events.
6. SCRUM-24 - build notification center from event data.
7. SCRUM-25 - build OTA progress screen after API shape is confirmed.
8. SCRUM-50 - add reachable/cloud status indicators using existing device/status data.

### Phase 3 - SCRUM-51 completion after dependencies

Person B can prepare mobile smoke evidence M1-M5 after the relevant mobile tickets land. Full SCRUM-51 closure still depends on Gateway-owned G* and E* cases.

## PR strategy

**Mode**: PR-per-ticket, not stacked.

Rules:

1. Branch names must follow `prefix/<jira-ticket-id>-<short-description>`.
2. PR title format: `[SCRUM-XX] <summary>`.
3. PR body includes `Closes SCRUM-XX` or `Refs SCRUM-XX` plus the Jira link.
4. Do not push empty branches.
5. Open mobile PRs from the matching ticket branch after the first feature commit.
6. Rebase each ticket branch on fresh `main` after its dependency merges.
7. Use squash-merge to keep `main` linear.

## Updated SCRUM-51 matrix ownership

| Group | Cases | Owner for implementation | Current status |
|---|---|---|---|
| Cloud API | C1-C8 | Backend/cloud owner | Skeleton exists; some behavior already implemented by SCRUM-45/46/49. |
| Gateway harness | G1-G7 | Gateway owner | External to this session. Do not touch `gateway/`. |
| Compose E2E | E1-E6 | Joint after Gateway work | Blocked until SCRUM-47/48 land. |
| Mobile smoke | M1-M5 | Person B | Plan and evidence can be prepared from mobile branches. |

## Mobile smoke acceptance

For Person B's SCRUM-51 contribution:

- M1: Login -> automation tab -> create rule from app.
- M2: Trigger event appears in notification center.
- M3: Edit rule action from app and verify the new behavior after backend support exists.
- M4: Delete rule from mobile and verify it disappears.
- M5: Network loss shows friendly error and the app does not crash.

Evidence file:

```text
docs/automation-e2e-report-YYYYMMDD.md
```

The report should reference screenshots or screencast paths plus the commit SHA that produced the app build.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| The spec re-plans tickets already merged on `main` | Treat `origin/main@0bf4ba7` as the baseline and avoid duplicate SCRUM-51 skeleton/Cloud PUT/DELETE/MQTT/event-log work. |
| Mobile work depends on backend fields that drift | Read `cloud/app/schemas.py`, `cloud/app/routers/automations.py`, and current mobile API models before each mobile ticket. |
| Gateway cases block full SCRUM-51 closure | Keep G* and gateway-dependent E* cases as external blockers. Person B prepares M* evidence only. |
| Branch names drift back to `feature/SCRUM-XX-*` | Use README rule: `feature/20-mobile-auth-session`, `docs/44-automation-contract-spec`, etc. |
| Dirty changes in the main checkout leak into docs work | Keep this planning branch isolated in a worktree and do not touch the original checkout's modified `README.md`. |

## Out of scope

- Editing any file under `gateway/`.
- Pushing empty branches.
- Recreating SCRUM-51 skeleton work that has already merged.
- Creating PRs from this planning session unless explicitly requested.
- Touching the dirty `README.md` in the original checkout.

## Next step

Use `superpowers:writing-plans` to produce a mobile-focused implementation plan for Phase 2 plus Person B's SCRUM-51 evidence contribution.
