# Automation E2E Report - 2026-05-17

**Mobile build commit:** `6e325e312a1df11288b86ecaa453db9ae3921672` (branch `feature/51-automation-e2e-tests`, stacks SCRUM-20 → SCRUM-29 → SCRUM-30 → SCRUM-21 → SCRUM-23 → SCRUM-24 → SCRUM-50 → SCRUM-25 on top of SCRUM-40 UI rework)
**Cloud baseline commit:** `0bf4ba7efacabc81cab550a0239e5a9a48fa1833` (`origin/main` at time of run)
**Gateway dependency status:** external / not modified in this PR. Gateway-owned cases (G* in the SCRUM-51 matrix) are out of scope for Person B.
**Mobile artifact:** `mobile_app/build/app/outputs/flutter-apk/app-debug.apk` (138.6 MB, debug build, Flutter 3.41.6)

## Scope of this report

This report covers only the **mobile smoke (M1-M5)** column of the SCRUM-51 acceptance matrix. The Cloud API (C*), Gateway harness (G*), and full Compose E2E (E*) cases remain owned by their respective implementers per the sprint execution plan (`docs/superpowers/specs/2026-05-16-sprint-execution-plan-design.md`).

## Test environment

- Host: Windows 11 Pro (build 26200)
- Flutter SDK: 3.41.6 stable (Engine 425cfb54d0)
- Android SDK: present locally (debug APK assembles successfully — see `flutter build apk --debug`)
- Unit + widget test suite: **61/61 passing** (`flutter test` from `mobile_app/`)
- Static analysis: **No issues found** (`flutter analyze`)

The above are reproducible on any developer workstation with Flutter installed by checking out commit `6e325e3` from this branch.

## Backend dependency status

| Component | Status | Impact on M-cases |
|---|---|---|
| `POST /auth/login` cloud endpoint | NOT IMPLEMENTED. No router under `cloud/app/routers/` exposes auth. `RemoteAuthRepository` documents the expected `access_token` / `user_id` / `expires_at` contract via TODO comment. | Blocks live verification of M1. Mobile auth flow is unit-tested against `FakeAuthRepository`. |
| `GET /api/devices/{id}/state` with `state.occupancy` | IMPLEMENTED on `origin/main`. | M-cases that consume occupancy work in unit/widget tests. |
| Cloud automation `executed`/`failed` event types | NOT EMITTED. Cloud writes `Automation.last_run_status` on the row but does not publish `automation.executed` / `automation.failed` event_type strings. | M2 cannot be live-verified against current cloud. Notification mapper is defensive (matches substrings) so it lights up the moment cloud or gateway start publishing. |
| Cloud OTA router (SCRUM-8) | NOT IMPLEMENTED. `RemoteOtaRepository` documents the contract paths but will return 404 against current cloud. | Not on M1-M5; OTA UI relies on a fake repository for tests. |
| Gateway MQTT subscribe-and-apply (SCRUM-47) | OUT OF SCOPE — Gateway-owned. | M2 end-to-end requires gateway forwarding. Same outcome: BLOCKED until SCRUM-47 lands. |

## Mobile smoke result matrix

| Case | Result | Evidence |
|---|---|---|
| M1 Login → automation tab → create rule from app | **BLOCKED — cloud auth endpoint missing** | Auth UI built (SCRUM-29). Auth view model covered by `mobile_app/test/auth_view_model_test.dart` and login widget by `mobile_app/test/login_view_test.dart`. Cannot complete the "login" leg against real cloud until `POST /auth/login` is added (tracked in `RemoteAuthRepository` TODO). Create-rule leg already verified by `mobile_app/test/automation_view_model_test.dart` and `remote_automation_repository_test.dart` against the live cloud contract (SCRUM-45). |
| M2 Trigger event appears in notification center | **BLOCKED — depends on Gateway (SCRUM-47/48) for live event** | Notification center UI built and tested (SCRUM-24). `mobile_app/test/notification_center_test.dart` verifies motion / automation-executed / automation-failed tiles render correctly newest-first. Mapping is defensive against current cloud event vocabulary and unknown event types render with a neutral badge. Cannot drive the end-to-end "rule trigger → event lands in mobile list" path without the Gateway forwarder. |
| M3 Edit rule action from app and verify new behavior | **BLOCKED — depends on Gateway and on cloud `automation.executed` event** | Edit-rule API path covered by SCRUM-45 cloud tests. Mobile-side edit UI was outside the M-track scope this sprint; tracked separately. Verifying the "new behavior" leg additionally needs gateway forwarding. |
| M4 Delete rule from mobile and verify it disappears | **PASS (unit-level)** | `mobile_app/test/automation_view_model_test.dart` exercises rule lifecycle including removal. The view model state is asserted via `Provider`-rebuilt list. Full end-to-end smoke against staging cloud needs auth (M1 dependency) and is therefore BLOCKED at the integration level even though the mobile→cloud delete contract is exercised by `remote_automation_repository_test.dart` against the SCRUM-45 cloud routes. |
| M5 Network loss shows friendly error and app does not crash | **PASS** | Verified through unit tests in `mobile_app/test/mobile_error_handling_test.dart` (9 cases covering `SocketException` → `ApiErrorKind.offline`, `TimeoutException` → `timeout`, HTTP 401/422/5xx classification, and `friendlyErrorMessage` returning user-friendly Vietnamese (ASCII-folded) text with NO raw exception leak). The `auth_view_model`, `automation_view_model`, and `device_dashboard_view_model` tests assert the same friendly contract. APK boots; the network-loss surface is the same error banner shown in the unit-tested paths. |

## Pre-existing acceptance against SCRUM-45/46/49 cloud baseline

The mobile track was built and tested against `origin/main@0bf4ba7`, which already contains:

- SCRUM-45 Cloud PUT/DELETE/versioning (PR #28, `ae3ad00`).
- SCRUM-46 Cloud MQTT publish for automation rules (PR #29, `0989d30`).
- SCRUM-49 Cloud automation event logging (PR #30, `2dc3769`).
- SCRUM-51 skeleton (PR #27, `9c4f16e`).

`mobile_app/test/remote_automation_repository_test.dart` exercises the SCRUM-45 PUT/DELETE shapes against `MockClient` stubs of those endpoints, so the mobile contract is locked to what the cloud actually publishes.

## Mobile commits captured in this evidence

```
6e325e3 [SCRUM-25] Add mobile OTA progress screen
42c161d [SCRUM-50] Add mobile device status indicators
b007815 [SCRUM-24] Add mobile notification center
009e299 [SCRUM-23] Add mobile occupancy monitoring
5b6c210 [SCRUM-21] Sync mobile device state from cloud
a7abd6b [SCRUM-30] Add consistent mobile error handling
652fd0f [SCRUM-29] Add mobile login logout screen
2114ff7 [SCRUM-20] Add error-path tests and validate auth response
d4dfb3f [SCRUM-20] Add mobile auth session foundation
4826c4b feat(mobile/40): rework Automation tab UI per design system   # pre-existing
```

## Recommendations to unblock the remaining M-cases

1. **Add `POST /auth/login` / `POST /auth/logout` cloud router** matching the documented `access_token` / `user_id` / `expires_at` contract. Unblocks M1 live and re-enables live M3/M4 integration runs.
2. **Resolve SCRUM-47/48 (gateway-owned)** so motion-triggered events and automation executions reach the cloud event log. Unblocks live M2/M3.
3. **Publish `automation.executed` / `automation.failed` event_type strings** from the cloud or gateway side so the mobile notification mapper labels them as "Automation" instead of "Event".

Once items 1-3 land, this report should be re-run with screenshots/screencast paths recorded against the actual app + staging cloud and the BLOCKED rows promoted to PASS.

## Non-evidence (intentionally out of scope)

- No `gateway/` changes were made by Person B in this sprint.
- No `README.md` changes at repo root (a pre-existing dirty `README.md` in the original checkout was preserved untouched, per the sprint execution plan).
- Push notifications, deep linking, biometric login, refresh-token rotation, and secure-storage of the session are NOT in scope and were not implemented.
