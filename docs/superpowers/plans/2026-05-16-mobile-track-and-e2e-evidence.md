# Mobile Track and E2E Evidence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish Person B's remaining mobile tickets and prepare the mobile evidence portion of SCRUM-51 without modifying Gateway code.

**Architecture:** Keep mobile changes inside `mobile_app/` and evidence changes inside `docs/`. Use the existing Flutter layered structure: data models/services, domain repositories/models, view models, then UI widgets/views. Treat Gateway behavior as an external dependency and only consume cloud/mobile-facing contracts.

**Tech Stack:** Flutter/Dart, Provider-style view models, FastAPI cloud API contracts, pytest cloud E2E skeleton for reference, Markdown docs for evidence.

---

## Scope Guard

Do not modify:

```text
gateway/
```

If a task needs Gateway behavior to be complete, record it as a blocker in the ticket PR and continue only with mobile-side or documentation work.

## File Structure

- Modify `mobile_app/lib/data/services/api_client.dart` for shared HTTP/session behavior only when needed by a ticket.
- Modify `mobile_app/lib/data/models/*.dart` when the cloud response shape requires a typed API model.
- Modify `mobile_app/lib/data/repositories/*.dart` for remote/mock repository behavior.
- Modify `mobile_app/lib/domain/models/*.dart` and `mobile_app/lib/domain/repositories/*.dart` for mobile-facing concepts.
- Modify `mobile_app/lib/ui/features/*/view_models/*.dart` for state and workflow logic.
- Modify `mobile_app/lib/ui/features/*/views/*.dart` and `mobile_app/lib/ui/features/*/widgets/*.dart` for UI.
- Modify or add tests under `mobile_app/test/`.
- Add SCRUM-51 mobile evidence under `docs/automation-e2e-report-YYYYMMDD.md` only after the relevant mobile flow is demonstrable.

## Task 1: SCRUM-20 Mobile Auth And Session

**Files:**
- Modify: `mobile_app/lib/data/services/api_client.dart`
- Create: `mobile_app/lib/domain/models/auth_session.dart`
- Create: `mobile_app/lib/domain/repositories/auth_repository.dart`
- Create: `mobile_app/lib/data/repositories/remote_auth_repository.dart`
- Create: `mobile_app/lib/ui/features/auth/view_models/auth_view_model.dart`
- Test: `mobile_app/test/auth_view_model_test.dart`

- [ ] **Step 1: Create a failing auth view-model test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/domain/models/auth_session.dart';
import 'package:zigbee_smart_building/domain/repositories/auth_repository.dart';
import 'package:zigbee_smart_building/ui/features/auth/view_models/auth_view_model.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    return AuthSession(
      accessToken: 'test-token',
      userId: 'operator-1',
      expiresAt: DateTime.utc(2026, 5, 16, 12),
    );
  }

  @override
  Future<void> logout() async {}
}

void main() {
  test('login stores an authenticated session', () async {
    final viewModel = AuthViewModel(repository: FakeAuthRepository());

    await viewModel.login(username: 'operator', password: 'password');

    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.session?.accessToken, 'test-token');
    expect(viewModel.errorMessage, isNull);
  });
}
```

- [ ] **Step 2: Run the focused test**

Run:

```powershell
cd mobile_app
flutter test test/auth_view_model_test.dart
```

Expected: FAIL until the real repository/view model exists.

- [ ] **Step 3: Implement the smallest session model and repository boundary**

Use `AuthSession` as a mobile-only object with `accessToken`, optional `userId`, and `expiresAt`. Keep refresh-token or secure-storage work out unless the ticket requires it.

- [ ] **Step 4: Implement `AuthViewModel`**

Expose `isLoading`, `isAuthenticated`, `session`, and `errorMessage`. Do not add UI yet.

- [ ] **Step 5: Re-run tests and commit**

Run:

```powershell
cd mobile_app
flutter test test/auth_view_model_test.dart
```

Commit:

```powershell
git add mobile_app/lib mobile_app/test/auth_view_model_test.dart
git commit -m "[SCRUM-20] Add mobile auth session foundation"
```

## Task 2: SCRUM-29 Login/Logout Screen

**Files:**
- Create: `mobile_app/lib/ui/features/auth/views/login_view.dart`
- Modify: `mobile_app/lib/ui/features/shell/views/smart_building_shell.dart`
- Test: `mobile_app/test/login_view_test.dart`

- [ ] **Step 1: Write a widget test for login success and logout visibility**

The test should pump the auth view with a fake repository, enter credentials, tap Login, and assert the app transitions to the authenticated shell.

- [ ] **Step 2: Run the widget test**

Run:

```powershell
cd mobile_app
flutter test test/login_view_test.dart
```

Expected: FAIL until `login_view.dart` exists.

- [ ] **Step 3: Build the login view**

Use existing theme/widgets where possible. Keep copy short and operational. Do not redesign unrelated screens.

- [ ] **Step 4: Wire logout**

Add logout only where the app already has a settings/profile surface. If no clear surface exists, use the smallest settings action rather than changing the main navigation model.

- [ ] **Step 5: Re-run tests and commit**

Run:

```powershell
cd mobile_app
flutter test test/login_view_test.dart
```

Commit:

```powershell
git add mobile_app/lib mobile_app/test/login_view_test.dart
git commit -m "[SCRUM-29] Add mobile login logout screen"
```

## Task 3: SCRUM-30 Mobile Error Handling

**Files:**
- Modify: `mobile_app/lib/ui/core/widgets/error_banner.dart`
- Modify: `mobile_app/lib/data/services/api_client.dart`
- Modify: relevant view models that currently surface raw exceptions
- Test: `mobile_app/test/mobile_error_handling_test.dart`

- [ ] **Step 1: Write tests for network failure and validation failure**

Cover one repository-level failure and one view-model-level friendly message.

- [ ] **Step 2: Run the focused test**

```powershell
cd mobile_app
flutter test test/mobile_error_handling_test.dart
```

- [ ] **Step 3: Normalize errors at the API/repository boundary**

Return stable mobile errors such as timeout, offline, validation, unauthorized, and unknown. Avoid leaking raw exception text to UI.

- [ ] **Step 4: Reuse the existing error banner**

Keep UI changes surgical. The goal is consistent behavior, not a new visual system.

- [ ] **Step 5: Re-run tests and commit**

```powershell
cd mobile_app
flutter test test/mobile_error_handling_test.dart
git add mobile_app/lib mobile_app/test/mobile_error_handling_test.dart
git commit -m "[SCRUM-30] Add consistent mobile error handling"
```

## Task 4: SCRUM-21 Real-Time Device State Sync

**Files:**
- Modify: `mobile_app/lib/data/repositories/remote_device_repository.dart`
- Modify: `mobile_app/lib/ui/features/devices/view_models/device_dashboard_view_model.dart`
- Test: `mobile_app/test/remote_device_repository_test.dart`
- Test: `mobile_app/test/device_dashboard_view_model_test.dart`

- [ ] **Step 1: Add a test for refreshing device state from the current cloud API**

Base the expected fields on `mobile_app/lib/data/models/device_state_api_model.dart` and existing cloud contract docs.

- [ ] **Step 2: Run tests**

```powershell
cd mobile_app
flutter test test/remote_device_repository_test.dart test/device_dashboard_view_model_test.dart
```

- [ ] **Step 3: Implement polling or refresh behavior using the existing repository pattern**

Do not introduce WebSocket/MQTT mobile transport unless the ticket explicitly requires it.

- [ ] **Step 4: Re-run tests and commit**

```powershell
cd mobile_app
flutter test test/remote_device_repository_test.dart test/device_dashboard_view_model_test.dart
git add mobile_app/lib mobile_app/test
git commit -m "[SCRUM-21] Sync mobile device state from cloud"
```

## Task 5: SCRUM-23 Occupancy Monitoring Screen

**Files:**
- Modify: `mobile_app/lib/ui/features/devices/views/devices_view.dart`
- Create: `mobile_app/lib/ui/features/devices/widgets/occupancy_status_card.dart`
- Test: `mobile_app/test/occupancy_monitoring_view_test.dart`

- [ ] **Step 1: Write a widget test for occupied and clear states**

Use fake device data. Assert clear labels, status badge, and timestamp behavior.

- [ ] **Step 2: Implement the smallest occupancy UI**

Use existing device state from SCRUM-21. Do not add new backend calls if current state already carries occupancy.

- [ ] **Step 3: Verify and commit**

```powershell
cd mobile_app
flutter test test/occupancy_monitoring_view_test.dart
git add mobile_app/lib mobile_app/test/occupancy_monitoring_view_test.dart
git commit -m "[SCRUM-23] Add mobile occupancy monitoring"
```

## Task 6: SCRUM-24 Notification Center

**Files:**
- Modify: `mobile_app/lib/data/models/event_api_model.dart`
- Modify: `mobile_app/lib/ui/features/logs/views/logs_view.dart`
- Create: `mobile_app/lib/ui/features/logs/widgets/notification_event_tile.dart`
- Test: `mobile_app/test/notification_center_test.dart`

- [ ] **Step 1: Write a test for event grouping and newest-first display**

Use fake events for motion, automation execution, and failed automation execution.

- [ ] **Step 2: Implement event mapping**

Keep Gateway event names as strings from the API contract. Do not add Gateway code.

- [ ] **Step 3: Implement notification UI and commit**

```powershell
cd mobile_app
flutter test test/notification_center_test.dart
git add mobile_app/lib mobile_app/test/notification_center_test.dart
git commit -m "[SCRUM-24] Add mobile notification center"
```

## Task 7: SCRUM-25 OTA Progress Screen

**Files:**
- Create: `mobile_app/lib/data/models/ota_api_model.dart`
- Create: `mobile_app/lib/domain/models/ota_campaign.dart`
- Create: `mobile_app/lib/domain/repositories/ota_repository.dart`
- Create: `mobile_app/lib/data/repositories/remote_ota_repository.dart`
- Modify: `mobile_app/lib/ui/features/settings/views/settings_view.dart`
- Test: `mobile_app/test/ota_progress_test.dart`

- [ ] **Step 1: Confirm current cloud OTA API before coding**

Read `docs/OTA_CAMPAIGN_CONTRACT.md` and cloud OTA routes. If no stable API exists, document the blocker in the PR and only add mock-driven UI behind a repository interface.

- [ ] **Step 2: Write a test for progress states**

Cover queued, running, succeeded, and failed progress rows.

- [ ] **Step 3: Implement the smallest progress view**

Keep OTA UI separate from Gateway behavior. It displays cloud state only.

- [ ] **Step 4: Verify and commit**

```powershell
cd mobile_app
flutter test test/ota_progress_test.dart
git add mobile_app/lib mobile_app/test/ota_progress_test.dart
git commit -m "[SCRUM-25] Add mobile OTA progress screen"
```

## Task 8: SCRUM-50 Device Reachable / Cloud Status Indicators

**Files:**
- Modify: `mobile_app/lib/domain/models/cloud_status.dart`
- Modify: `mobile_app/lib/ui/features/home/widgets/gateway_status_card.dart`
- Modify: `mobile_app/lib/ui/features/automation/widgets/rule_status_row.dart`
- Test: `mobile_app/test/device_status_indicators_test.dart`

- [ ] **Step 1: Write tests for online, offline, syncing, and unknown indicators**

Use existing `CloudStatus` and device model fields before adding new state.

- [ ] **Step 2: Implement status mapping**

Map API/device state to UI badges. Avoid implying Gateway confirmation when the API does not expose it.

- [ ] **Step 3: Verify and commit**

```powershell
cd mobile_app
flutter test test/device_status_indicators_test.dart
git add mobile_app/lib mobile_app/test/device_status_indicators_test.dart
git commit -m "[SCRUM-50] Add mobile device status indicators"
```

## Task 9: SCRUM-51 Mobile Smoke Evidence

**Files:**
- Create: `docs/automation-e2e-report-YYYYMMDD.md`
- Reference only: `cloud/tests/test_automation_e2e.py`
- Reference only: `docs/automation-e2e-plan.md`

- [ ] **Step 1: Build or run the mobile app for evidence**

```powershell
cd mobile_app
flutter test
flutter build apk --debug
```

- [ ] **Step 2: Capture M1-M5 evidence**

Capture the mobile smoke cases:

- M1 Login -> automation tab -> create rule.
- M2 Trigger event appears in notification center.
- M3 Edit rule action and verify new behavior if backend/Gateway dependencies are ready.
- M4 Delete rule from mobile.
- M5 Network loss shows friendly error and no crash.

- [ ] **Step 3: Write the evidence report**

The report must include:

```markdown
# Automation E2E Report - YYYY-MM-DD

**Mobile build commit:** output of `git rev-parse HEAD` from the mobile ticket branch
**Cloud baseline commit:** output of `git rev-parse origin/main`
**Gateway dependency status:** external / not modified in this PR

| Case | Result | Evidence |
|---|---|---|
| M1 | PASS or BLOCKED | repo-relative screenshot or screencast path captured during execution |
| M2 | PASS or BLOCKED | repo-relative screenshot or screencast path captured during execution |
| M3 | PASS or BLOCKED | repo-relative screenshot or screencast path captured during execution |
| M4 | PASS or BLOCKED | repo-relative screenshot or screencast path captured during execution |
| M5 | PASS or BLOCKED | repo-relative screenshot or screencast path captured during execution |
```

- [ ] **Step 4: Commit**

```powershell
git add docs/automation-e2e-report-YYYYMMDD.md
git commit -m "[SCRUM-51] Add mobile smoke evidence report"
```

## Verification Before PRs

Run these before each mobile PR:

```powershell
cd mobile_app
flutter test
```

Run this before any PR that claims cloud/E2E compatibility:

```powershell
pytest cloud/tests -q
```

Do not claim SCRUM-51 is fully complete until Gateway-owned G* and Gateway-dependent E* cases are implemented by the Gateway owner.
