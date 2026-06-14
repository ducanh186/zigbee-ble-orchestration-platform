# Developer Guide

This repo is easier to work in when each change stays small. Pick the layer you are changing, prove the contract you depend on, and run focused checks before widening the scope.

## Setup

### Cloud

```powershell
cd cloud
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m pytest cloud/tests -q
```

If you run from the repo root, keep imports aligned with the package layout:

```powershell
python -m pytest cloud/tests -q
python -m compileall cloud/app
```

### Mobile

```powershell
cd mobile_app
flutter pub get
flutter test
flutter analyze
```

### Gateway

The gateway runs against the **EC2 production broker by default** (`98.83.4.87:8883`, TLS + mTLS) so cloud commands and schedule automations reach it:

```bash
bash scripts/start-gateway-cloud.sh
```

Use `scripts/start-gateway.sh` (localhost:1883) only for offline local-dev when the cloud broker is unreachable. See [`OPERATIONS.md`](OPERATIONS.md) → "Gateway Run" for details.

### Deploy Scripts

PowerShell is the default shell on this machine. Use PowerShell syntax for multiline scripts and temp files. Do not paste Bash heredocs into PowerShell.

For deploy script syntax checks, use the appropriate shell for each script:

```powershell
powershell -NoProfile -Command "Get-Command powershell"
sh -n deploy/deploy.sh
```

## Coding Workflow

1. Confirm the target branch and current worktree state.
2. Read live source and config before trusting old markdown.
3. Define the contract being changed: REST route, MQTT topic, payload field, database status, or UI behavior.
4. Keep edits surgical. Do not refactor neighboring code unless the requested change needs it.
5. Add or update tests for behavior, not for guessed implementation details.
6. Run focused checks.
7. Use `git status` and `git diff --check` before handing off.

## Branch And Jira Expectations

For implementation PRs, create or confirm the Jira SCRUM issue before creating the branch. Use a clean branch for each scoped slice. Avoid stacking docs, design files, local artifacts, and runtime changes unless the PR explicitly needs that combination.

Good branch names are short and scoped, for example:

```text
codex/provisioning-session-scope
codex/mqtt-acl-hardening
codex/docs-lean-english
```

Update Jira conservatively. Mark work done only after source, tests, deploy logs, API responses, or device evidence prove it.

## Test Strategy

| Change type | Minimum checks |
|---|---|
| Cloud router/auth/access control | Focused `pytest`, then `python -m pytest cloud/tests -q`. |
| Cloud model/schema change | ORM import check, focused tests, migration/schema review. |
| MQTT topic or payload change | Cloud MQTT tests plus Gateway topic handling review. |
| Mobile API behavior | `flutter test`, `flutter analyze`, and focused repository/service tests. |
| Gateway command handling | Gateway compile/test path where available plus MQTT contract review. |
| Deploy script change | PowerShell parse sanity, shell syntax check for `.sh`, and dry-run reasoning from env examples. |
| Docs-only change | Doc inventory, English-only scan, internal-link check, `git diff --check`. |

## Contract-Safe Development

Do not rename public contracts without explicit approval:

- REST routes and payload fields.
- MQTT topic segments.
- Command `op` names.
- Device capability names.
- Database-visible enum/status values.
- CSV, schema, or deploy environment variable names.

When a contract must change, update both sides in the same PR: producer, consumer, tests, and docs.

## Practical Example

If a user reports that a light ON command times out:

1. Check whether Mobile got a command id from Cloud.
2. Check the Cloud command row status.
3. Check whether Cloud published `commands/{command_id}/request`.
4. Check whether Gateway was connected to MQTT.
5. Check Gateway logs for command receipt.
6. Check the Zigbee action and command reply.

That order keeps the debugging boundary clear. If Cloud created the command and later timed it out while the broker had no gateway client, the likely next task is Gateway MQTT connectivity, not Mobile UI.
