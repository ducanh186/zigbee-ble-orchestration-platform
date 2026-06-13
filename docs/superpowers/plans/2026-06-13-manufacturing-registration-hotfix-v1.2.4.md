# Manufacturing Registration Hotfix v1.2.4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task.

**Goal:** Ship `v1.2.4` with PowerShell and Ubuntu manufacturing CLIs that
upload Install Codes to Cloud while keeping QR labels public and secret-free.

**Architecture:** The two native CLIs implement the same HTTP contract. They
first register the secret through the existing factory-device endpoint, then
request a public label through the existing label endpoint. Mobile continues
to scan only public identity data; Cloud resolves the Install Code and sends it
to Gateway through `gateway.prepare_join`.

**Tech Stack:** PowerShell 5.1+, Bash, `curl`, Python standard-library
`unittest`, FastAPI/pytest, Flutter/Dart, Android ADB, GitHub CLI.

**Design:** `docs/superpowers/specs/2026-06-13-manufacturing-registration-hotfix-v1.2.4-design.md`

---

## Task 1: Add a failing cross-platform CLI contract test

**Files:**

- Create: `deploy/tests/test_manufacturing_register_cli.py`
- Test: `deploy/tests/test_manufacturing_register_cli.py`

- [ ] **Step 1: Write the failing test**

Create a Python standard-library test server that records requests and returns:

- `201` plus `has_install_code: true` for
  `/api/provisioning/factory-devices`
- `201` plus `payload`, `payload_json`, and `qr_svg` for
  `/api/provisioning/labels`

Test both available runtimes:

- PowerShell: `powershell.exe` or `pwsh`
- Ubuntu mapping: `bash`

Assert:

- factory registration is the first request;
- label creation is the second request;
- only factory registration contains `install_code`;
- label payload and generated `payload.json` do not contain `install_code`;
- generated `label.svg` contains SVG;
- stdout/stderr never contain the Install Code or access token;
- missing token exits non-zero before any HTTP request;
- a failed factory request exits non-zero without echoing the response body.

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
python deploy/tests/test_manufacturing_register_cli.py
```

Expected: failure because `deploy/manufacturing-register.ps1` and
`deploy/manufacturing-register.sh` do not exist.

- [ ] **Step 3: Commit the failing test**

```powershell
git add deploy/tests/test_manufacturing_register_cli.py
git commit -m "test: define manufacturing registration CLI contract"
```

## Task 2: Implement the PowerShell manufacturing CLI

**Files:**

- Create: `deploy/manufacturing-register.ps1`
- Test: `deploy/tests/test_manufacturing_register_cli.py`

- [ ] **Step 1: Implement the minimum PowerShell behavior**

Add parameters:

- mandatory `Eui64`, `InstallCode`, and `DeviceType`;
- optional `Model` and `OutputDirectory`;
- optional `ApiBaseUrl` defaulting from `SB_API_BASE_URL`, then
  `https://dashboard.iot-building.app`.

Read the admin bearer token only from `SB_MANUFACTURING_ACCESS_TOKEN`.

Validate EUI-64 and device type locally. Do not print the token, Install Code,
request body, or factory endpoint response body.

Call:

1. `POST /api/provisioning/factory-devices`
2. `POST /api/provisioning/labels`

Require `has_install_code: true`, then write UTF-8 `payload.json` and
`label.svg`. Refuse to overwrite existing output files.

- [ ] **Step 2: Run the PowerShell-focused test to verify GREEN**

Run:

```powershell
python deploy/tests/test_manufacturing_register_cli.py PowerShellManufacturingCliTests
```

Expected: all PowerShell tests pass; Bash tests may still fail because its
script is not implemented.

- [ ] **Step 3: Commit**

```powershell
git add deploy/manufacturing-register.ps1 deploy/tests/test_manufacturing_register_cli.py
git commit -m "feat: add PowerShell manufacturing registration CLI"
```

## Task 3: Map the same contract to Ubuntu Bash

**Files:**

- Create: `deploy/manufacturing-register.sh`
- Modify: `deploy/tests/test_manufacturing_register_cli.py`
- Test: `deploy/tests/test_manufacturing_register_cli.py`

- [ ] **Step 1: Add or enable Bash parity assertions**

Ensure the same fixture and assertions apply to Bash:

- same environment names;
- same required inputs;
- same endpoint order and JSON fields;
- same output filenames;
- same no-secret output behavior;
- same non-zero failure semantics.

- [ ] **Step 2: Verify RED for Bash**

Run:

```powershell
python deploy/tests/test_manufacturing_register_cli.py BashManufacturingCliTests
```

Expected: failure because the Bash implementation is absent or incomplete.

- [ ] **Step 3: Implement the minimum Bash behavior**

Use strict mode, `curl`, temporary files with cleanup traps, and Python only
for structured JSON parsing/serialization where shell string manipulation
would be unsafe.

Do not include secrets in command tracing or error output. Send JSON through
stdin or a protected temporary file, not through a visible command argument.

- [ ] **Step 4: Verify GREEN for both CLIs**

Run:

```powershell
python deploy/tests/test_manufacturing_register_cli.py
bash -n deploy/manufacturing-register.sh
```

Expected: all available-runtime tests pass and Bash syntax is valid.

- [ ] **Step 5: Commit**

```powershell
git add deploy/manufacturing-register.sh deploy/tests/test_manufacturing_register_cli.py
git commit -m "feat: add Ubuntu manufacturing registration CLI"
```

## Task 4: Enforce the public QR contract in Cloud, Mobile, and Webdev

**Files:**

- Modify: `cloud/tests/test_provisioning_labels.py`
- Modify: `cloud/webdev/index.html`
- Modify: `cloud/webdev/app.js`
- Modify: `mobile_app/lib/domain/models/provisioning_session.dart`
- Modify: `mobile_app/test/provisioning_model_test.dart`
- Test: `cloud/tests/test_provisioning_labels.py`
- Test: `mobile_app/test/provisioning_model_test.dart`

- [ ] **Step 1: Add failing QR security assertions**

Cloud test:

- decode `payload_json`;
- assert its exact keys are `version`, `eui64`, and `device_type`;
- assert neither API payload nor SVG contains the valid test Install Code.

Mobile test:

- verify a normal public QR parses;
- verify a QR containing `install_code` is rejected with `FormatException`
  rather than silently accepting secret-bearing input.

Webdev contract check:

- assert label creation JavaScript has no `install_code` or
  `labelInstallCodeInput` reference.

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```powershell
docker compose run --rm cloud-api pytest -q cloud/tests/test_provisioning_labels.py
Set-Location mobile_app
flutter test test/provisioning_model_test.dart
```

Expected: at least the Mobile rejection and stale Webdev contract fail before
implementation.

- [ ] **Step 3: Make the smallest production changes**

- Remove the Install Code input from the label form.
- Remove label JavaScript that sends or reads `install_code`.
- Keep factory registration separate from public label generation.
- Reject `install_code` in `ProvisioningQrPayload.fromJson`.
- Do not change the public QR field names or provisioning-session request.

- [ ] **Step 4: Verify GREEN**

Run the focused Cloud and Flutter tests again.

- [ ] **Step 5: Commit**

```powershell
git add cloud/tests/test_provisioning_labels.py cloud/webdev/index.html cloud/webdev/app.js mobile_app/lib/domain/models/provisioning_session.dart mobile_app/test/provisioning_model_test.dart
git commit -m "fix: keep provisioning QR payloads secret-free"
```

## Task 5: Add manufacturing and Gateway handoff documentation

**Files:**

- Modify: `docs/CONTRACTS.md`
- Modify: `docs/SECURITY.md`
- Create: `docs/handoffs/MANUFACTURING_INSTALL_CODE_GATEWAY_HANDOFF.md`
- Create: `docs/MANUFACTURING_PROVISIONING.md`

- [ ] **Step 1: Correct the contract documentation**

State explicitly:

- manufacturing uploads the Install Code to Cloud;
- QR contains only public identity;
- Mobile never needs or stores the Install Code;
- Cloud resolves the secret by EUI-64;
- Gateway receives it only through `gateway.prepare_join`.

- [ ] **Step 2: Write the operator runbook**

Document PowerShell first and Ubuntu Bash second, including:

- environment variables;
- safe invocation examples using placeholders;
- generated files;
- rerun behavior;
- secret-handling cautions;
- test/staging procedure before production use.

- [ ] **Step 3: Write the Gateway continuation handoff**

Cover:

- EUI-64 keyed join staging;
- bounded join duration;
- CRC handling;
- no-secret logging;
- success/failure acknowledgement;
- the separate schedule `unsupported_trigger` backlog and reproduction
  evidence.

- [ ] **Step 4: Check docs for contradictions**

Run:

```powershell
rg -n "QR.*install|install.*QR|install_code" docs cloud/webdev mobile_app/lib
```

Expected: all remaining references describe the server-side secret boundary;
no documentation instructs operators to print the Install Code in QR.

- [ ] **Step 5: Commit**

Markdown is ignored by the repository, so stage only the intended docs:

```powershell
git add -f docs/CONTRACTS.md docs/SECURITY.md docs/MANUFACTURING_PROVISIONING.md docs/handoffs/MANUFACTURING_INSTALL_CODE_GATEWAY_HANDOFF.md
git commit -m "docs: hand off secure manufacturing provisioning"
```

## Task 6: Set the mobile hotfix version and run regression tests

**Files:**

- Modify: `mobile_app/pubspec.yaml`
- Verify: all intended existing branch changes

- [ ] **Step 1: Bump the app version**

Change:

```yaml
version: 1.2.4+1204
```

- [ ] **Step 2: Run focused Cloud tests**

Run the provisioning, label, schedule migration, and automation API tests.

- [ ] **Step 3: Run the full Cloud suite**

Run:

```powershell
docker compose run --rm cloud-api pytest -q
```

Record unrelated pre-existing failures separately; no new failure may be
introduced by this hotfix.

- [ ] **Step 4: Run Flutter checks**

Run:

```powershell
Set-Location mobile_app
flutter analyze
flutter test
```

Expected: analysis succeeds and the full Flutter test suite passes.

- [ ] **Step 5: Commit the version and any test-only adjustments**

```powershell
git add mobile_app/pubspec.yaml
git commit -m "chore: bump Android hotfix version to 1.2.4"
```

## Task 7: Build and test the production APK

**Files:**

- Build output: `mobile_app/build/app/outputs/flutter-apk/app-release.apk`
- Runtime evidence: local only, not committed

- [ ] **Step 1: Build**

Run:

```powershell
Set-Location mobile_app
flutter build apk --release --dart-define=API_BASE_URL=https://dashboard.iot-building.app
```

- [ ] **Step 2: Record artifact identity**

Record:

- byte size;
- SHA-256;
- Android `versionName=1.2.4`;
- Android `versionCode=1204`.

- [ ] **Step 3: Install through ADB**

Install the APK on the connected Android target and launch
`com.smartbridge.zigbee_smart_building`.

- [ ] **Step 4: Smoke-test**

Verify:

- login reaches `https://dashboard.iot-building.app`;
- automation list loads;
- event rule creation succeeds;
- schedule rule creation reaches Cloud without HTTP 5xx;
- public provisioning QR parses;
- no Android crash appears in logcat.

The known Gateway schedule `unsupported_trigger` response is documented, not
treated as an app/Cloud regression.

## Task 8: Final review, publish PR, and release v1.2.4

**Files:**

- Review: all tracked changes on `fix/mobile-login-api-base-url`
- Release asset: verified `app-release.apk`

- [ ] **Step 1: Run verification-before-completion**

Use `superpowers:verification-before-completion`. Re-run all commands required
to support the final claims and inspect the final diff for secrets and
unrelated artifacts.

- [ ] **Step 2: Commit the integrated hotfix**

Stage only intended source, tests, l10n, docs, and version files. Do not stage
screenshots, design exports, archives, or local release directories.

- [ ] **Step 3: Push and create a ready PR**

Push `fix/mobile-login-api-base-url` and open a ready pull request against
`main` with:

- root cause and Cloud fix;
- schedule redesign and mobile API base URL fix;
- manufacturing/QR security contract;
- test and ADB evidence;
- Gateway continuation items.

- [ ] **Step 4: Publish GitHub release**

Create tag/release `v1.2.4` from the verified hotfix commit and attach only the
verified APK. Include SHA-256 and known Gateway schedule limitation in release
notes.

- [ ] **Step 5: Verify publication**

Confirm:

- branch exists on origin;
- PR URL is reachable;
- release tag points to the intended commit;
- APK asset size and SHA-256 match the locally verified artifact.
