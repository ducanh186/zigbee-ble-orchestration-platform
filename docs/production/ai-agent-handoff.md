# AI Agent Handoff - Production Hardening Session

Last updated: 2026-06-01 04:35:00 +07:00

Jira: SCRUM-100

Status: HANDOFF_READY

## Purpose

This handoff gives the next AI agent enough context to continue the production-hardening work without replaying the whole session. It summarizes what was shipped, what was deployed, what was released, and what must not be claimed yet.

## Current Repository State

| Item | Value |
|---|---|
| Repository | `ducanh186/zigbee-ble-orchestration-platform` |
| Working handoff branch | `codex/scrum-90-ai-agent-handoff` |
| Base commit | `origin/main` at `3be1cc3` |
| Release tag | `v0.9.0-rc.1` |
| Release type | GitHub pre-release / release candidate |
| Release URL | `https://github.com/ducanh186/zigbee-ble-orchestration-platform/releases/tag/v0.9.0-rc.1` |
| Production readiness | `NOT_PRODUCTION_READY` |

Do not claim stable production readiness. The repository evidence plan is complete locally, but live/operator validation remains open.

## Merged Work In This Session

| Phase | Jira | Branch | PR | Merge commit | Summary |
|---|---|---|---|---|---|
| 2 | SCRUM-94 | `codex/scrum-90-phase2-auth` | #66 | `b5237fb` | Backend REST auth/RBAC, command auth, admin-only commissioning. |
| 3 | SCRUM-95 | `codex/scrum-90-phase3-mqtt-hardening` | #67 | `07da437` | Production MQTT TLS/mTLS config and strict ACL. |
| 4 | SCRUM-96 | `codex/scrum-90-phase4-gateway-config` | #68 | `aad6cca` | Gateway production config hardening and removal of dangerous defaults. |
| 5 | SCRUM-97 | `codex/scrum-90-phase5-secure-commissioning` | #69 | `12d9c0d` | Gateway `gateway.prepare_join` parsing and secure commissioning dispatch. |
| 6 | SCRUM-98 | `codex/scrum-90-phase6-ops-runbooks` | #70 | `ea188b4` | Backup/restore/monitoring/alerting runbook and Mosquitto log persistence. |
| 7 | SCRUM-99 | `codex/scrum-90-phase7-release-evidence` | PR #71 | `3be1cc3` | Release candidate docs, rollback, final evidence, and pre-release notes. |

The Jira parent is `SCRUM-90`. The handoff documentation task is `SCRUM-100`.

## Release Created

GitHub pre-release:

```text
v0.9.0-rc.1
Target commit: 3be1cc3419c9c26af40a7c4b2f316a505a04a490
URL: https://github.com/ducanh186/zigbee-ble-orchestration-platform/releases/tag/v0.9.0-rc.1
```

Release notes source:

```text
docs/production/release-notes-v0.9.0-rc.1.md
```

Important: this is a release candidate, not a stable production release.

## EC2 Deploy Evidence

User requested an EC2 deploy after Phase 6. The deploy was completed with the existing script:

```text
deploy/deploy.ps1
```

Deploy source:

```text
main after PR #70
commit: ea188b4
```

Post-deploy verification:

```text
GET http://<EC2_HOST>:8000/health -> {"status":"ok","version":"0.1.0"}
sb-cloud-api -> healthy
sb-mosquitto -> healthy
sb-postgres -> healthy
```

Do not write the raw EC2 host, SSH key path, or passwords into tracked docs. The deploy config lives in ignored `deploy/.env.deploy` on the operator machine. If the next agent needs exact host/key values, read that ignored file locally or check the Jira evidence comment on `SCRUM-90`.

## Verification Evidence

Latest local verification before Phase 7 merge:

```text
python -m pytest cloud/tests -q -> 156 passed, 21 skipped
python -m pytest cloud/tests/test_production_operations_contract.py cloud/tests/test_release_readiness_contract.py -q -> 6 passed
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml config -> PASS
git diff --check -> exit 0
Phase 7 release docs/source scan -> PASS
```

Release verification after creation:

```text
gh release view v0.9.0-rc.1 --json tagName,isPrerelease,targetCommitish,url,name
isPrerelease: true
targetCommitish: 3be1cc3419c9c26af40a7c4b2f316a505a04a490
```

## Important Files

| File | Why it matters |
|---|---|
| `docs/production/production-final-report.md` | Final evidence and explicit `NOT_PRODUCTION_READY` status. |
| `docs/production/production-release.md` | Release candidate and rollback runbook. |
| `docs/production/release-notes-v0.9.0-rc.1.md` | GitHub release notes source. |
| `docs/production/production-progress.html` | Dashboard showing Phase 0-7 local evidence complete. |
| `docs/production/production-operations.md` | Backup, restore, monitoring, alerting runbook. |
| `docs/production/production-commissioning.md` | Secure commissioning and live negative test procedure. |
| `deploy/docker-compose.prod-secure.yml` | Secure compose target; not yet used by the legacy EC2 deploy script. |
| `deploy/deploy.ps1` | Current EC2 deploy path; still uses legacy `docker-compose.prod.yml`. |
| `cloud/tests/test_release_readiness_contract.py` | Guards release evidence docs. |
| `cloud/tests/test_production_operations_contract.py` | Guards operations docs and compose persistence evidence. |

Markdown files may be ignored by repo rules. When adding new `docs/**/*.md`, use `git add -f`.

## Open Risks / Do Not Claim Closed

1. Secure compose cutover is not deployed to EC2 yet.
   - Next work should treat secure compose cutover as the primary production-readiness blocker.
   - Current EC2 deploy uses legacy `docker-compose.prod.yml`.
   - It exposes legacy demo ports in the deployed stack.

2. Live MQTT mTLS negative tests are pending.
   - Need operator-approved certificates and environment.

3. Live gateway hardware startup validation is pending.
   - Gateway production env/cert paths must be verified on real hardware.

4. Zigbee default global key rejection evidence is pending.
   - Source config and local tests are in place, but live radio negative evidence is not captured.

5. Real backup/restore dry-run evidence is pending.
   - Run in an operator-approved environment before stable release.

6. Cloud-App auth hardening now has a follow-up PR in progress.
   - The follow-up covers Cloud endpoint auth/scoping gaps, Mobile release guard, and the `SB_AUTH_TOKEN_SECRET` env canonical name.
   - Do not treat this as stable production readiness until the PR is merged and live/operator validation is captured.

7. Stable production release is deferred.
   - Current release is `v0.9.0-rc.1` pre-release only.

## Recommended Next Actions

1. Create a new SCRUM subtask for secure EC2 compose cutover.
2. Update `deploy/deploy.ps1` or add a separate secure deploy script that uses `deploy/docker-compose.prod-secure.yml`.
3. Prepare operator-managed cert directories for Nginx and MQTT:
   - `NGINX_CERT_DIR`
   - `MQTT_CERT_DIR`
4. Run secure compose config check and then deploy to EC2.
5. Verify EC2 no longer exposes direct public API/MQTT/Postgres demo ports.
6. Capture live MQTT mTLS negative evidence.
7. Capture live gateway startup evidence.
8. Capture Zigbee default global key rejection evidence.
9. Run backup/restore dry-run in an isolated environment.
10. Only after all live evidence is attached, create a stable release.

## Collaboration / Tooling Notes

- Use PowerShell syntax on Windows. Avoid Bash heredoc patterns.
- Use context-mode for broad file analysis to avoid flooding context.
- Use TDD for code or contract changes: write a failing test, verify RED, implement, verify GREEN.
- Before claiming completion, run fresh verification in the same turn.
- For each SCRUM-sized phase: create/update Jira, commit, push, open PR, merge to `main`, then update Jira.
- Do not commit real secrets, private keys, cert contents, or raw `.env.deploy`.
