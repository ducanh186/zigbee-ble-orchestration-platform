# Production Hardening Plan

Last updated: 2026-06-01 02:12:02 +07:00

Jira: SCRUM-90

Status: PHASE_0_VERIFIED

## Execution Model

Option 1 is approved: implement the production-hardening work as small SCRUM-sized phases. Each phase must:

1. Update `docs/production/production-progress.html`.
2. Record evidence in the relevant production document.
3. Run the smallest relevant verification command.
4. Commit only after the phase is complete and verified.
5. Push the corresponding branch.
6. Create a PR targeting `main`.
7. Merge only after review and checks are acceptable.

Current branch/worktree for Phase 0:

```text
Branch: codex/scrum-90-production-hardening
Worktree: C:\tmp\zigbee-scrum90-production-hardening
Base: local main at 5bc9eb1
```

## Phase Breakdown

| Phase | Goal | Primary files | Verification | Commit gate |
|---|---|---|---|---|
| 0 | Establish production scope, audit, env contract, dashboard, and acceptance checklist. | `docs/production/*`, `deploy/.env.prod.example` | Markdown/path checks, no placeholder scan, git diff review. | All required Phase 0 files exist and contain evidence. |
| 1 | Add public exposure lockdown and HTTPS reverse-proxy contract. | Nginx/deploy docs and compose changes. | Config syntax checks where tooling exists; documented security group rules. | API/DB/MQTT direct exposure removed from production path. |
| 2 | Add REST API authentication and authorization. | Cloud auth routes, models, dependencies, tests; mobile auth alignment. | Auth tests for 401/403/success role cases. | Protected high-risk endpoints pass negative/positive tests. |
| 3 | Harden MQTT with TLS/mTLS and strict ACL. | Mosquitto config, deploy env/docs, MQTT client config/tests. | Mosquitto config validation and documented negative tests. | Plain public MQTT disabled or internal-only; mTLS intent covered. |
| 4 | Harden gateway config and remove dangerous production fallbacks. | Gateway config/start scripts/runbook. | Fail-fast config tests or runbook command checks. | Production mode cannot silently use demo fallback values. |
| 5 | Harden Zigbee secure commissioning. | Gateway/cloud commissioning docs/tests and safe source files. | Admin-only permit join tests and commissioning negative procedure. | Default-key join rejection is documented or proven by tests/logs. |
| 6 | Add backup, restore, monitoring, and alerting runbooks. | Deploy scripts/docs/monitoring checklist. | Backup and restore dry-run where environment allows. | Recovery evidence exists or is explicitly not testable here. |
| 7 | Add CI/CD, release, rollback, and final evidence. | Final report, release checklist, rollback docs. | Full acceptance checklist. | No production readiness claim unless all acceptance items pass. |

## Phase 0 Detailed Tasks

### Files

- Create `docs/production/production-security-audit.md`.
- Create `docs/production/production-hardening-plan.md`.
- Create `docs/production/production-acceptance-checklist.md`.
- Create `docs/production/production-progress.html`.
- Create `docs/production/production-final-report.md`.
- Create `deploy/.env.prod.example`.

### Environment Contract

Production configuration must use placeholders and environment variables only:

```text
PROD_DOMAIN=<PROD_DOMAIN>
SB_API_HOST=127.0.0.1
SB_API_PORT=8000
SB_DATABASE_URL=postgresql+asyncpg://<DB_USER>:<DB_PASSWORD>@postgres:5432/<DB_NAME>
SB_JWT_SECRET=<JWT_SECRET>
SB_MQTT_HOST=mosquitto
SB_MQTT_PORT=8883
SB_MQTT_USERNAME=<MQTT_CLIENT_USERNAME>
SB_MQTT_PASSWORD=<MQTT_CLIENT_PASSWORD>
SB_MQTT_CA_CERT_PATH=<MQTT_CA_CERT_PATH>
SB_MQTT_CLIENT_CERT_PATH=<MQTT_CLIENT_CERT_PATH>
SB_MQTT_CLIENT_KEY_PATH=<MQTT_CLIENT_KEY_PATH>
```

Do not put real secrets, private keys, JWT secrets, database passwords, or certificate private keys in repository files or command output.

### Acceptance Criteria

- `docs/production/` exists.
- All five required production output files exist.
- `deploy/.env.prod.example` exists and contains placeholder-only production values.
- Audit report includes evidence and `Needs confirmation` entries where evidence is missing.
- Progress dashboard includes overall status, phase summary, checklist, evidence links, test results, risk register, next actions, and change log.
- Final report states that production readiness is not claimed yet.

## Jira Workflow

- Parent: `SCRUM-90` tracks the main production-hardening workstream.
- Subtasks track independent work packages, for example `SCRUM-91` for mobile login-state architecture.
- Status must match code state:
  - `To Do`: not started.
  - `In Progress`: actively being worked.
  - `Done`: verified, committed, pushed, PR created/merged as applicable.

## Open Dependencies

- `SCRUM-91` mobile login-state subagent is running separately.
- Backend auth endpoints need Phase 2 implementation; Phase 0 does not invent endpoint behavior.
- Live EC2 validation is outside local Phase 0 and must be marked `not testable in this environment` unless run later with operator approval.

## Phase 0 Verification

Command:

```text
node-based artifact verification via context-mode
```

Result:

```text
PASS
```

Evidence checked:

- Required files exist.
- No unfinished-marker strings in new Phase 0 artifacts.
- No known demo IP or demo credential strings are repeated in new Phase 0 artifacts.
- No private key block marker appears in new Phase 0 artifacts.
