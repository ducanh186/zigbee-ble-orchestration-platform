# Production Hardening Plan

Last updated: 2026-06-01 03:58:00 +07:00

Jira: SCRUM-90

Status: PHASE_6_OPERATIONS_VERIFIED_LOCALLY

## Execution Model

Option 1 is approved: implement the production-hardening work as small SCRUM-sized phases. Each phase must:

1. Update `docs/production/production-progress.html`.
2. Record evidence in the relevant production document.
3. Run the smallest relevant verification command.
4. Commit only after the phase is complete and verified.
5. Push the corresponding branch.
6. Create a PR targeting `main`.
7. Merge only after review and checks are acceptable.

Current active branch/worktree:

```text
Branch: codex/scrum-90-phase6-ops-runbooks
Worktree: C:\tmp\zigbee-scrum90-production-hardening
Base: origin/main after PR 69 merge
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
- Backend Phase 2 auth/RBAC is locally verified, but mobile login-state integration still needs `SCRUM-91` output.
- Live EC2 validation is outside local phases and must be marked `not testable in this environment` unless run later with operator approval.
- Live Zigbee default global key rejection needs operator hardware evidence before final production readiness is claimed.
- Real backup and restore dry-run evidence needs an operator-approved environment before final production readiness is claimed.

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

## Phase 1 Verification

Command:

```text
python -m pytest cloud/tests/test_production_exposure_contract.py -q
```

Result:

```text
2 passed in 0.06s
docker compose config PASS
```

Evidence checked:

- `deploy/docker-compose.prod-secure.yml` maps only public reverse-proxy ports `80` and `443`.
- `deploy/docker-compose.prod-secure.yml` does not map host ports `8000`, `1883`, or `5432`.
- `deploy/nginx/prod.conf` redirects HTTP to HTTPS.
- `deploy/nginx/prod.conf` proxies HTTPS traffic to internal `cloud-api:8000`.
- `docs/production/production-networking.md` documents security group intent and local test limitations.
- `docker compose --env-file .env.prod -f docker-compose.prod-secure.yml config` parses the secure compose file.

## Phase 2 Verification

Command:

```text
python -m pytest cloud/tests/test_auth_rbac.py cloud/tests/test_commands.py cloud/tests/test_gateways.py -q
```

Result:

```text
23 passed in 9.54s
```

Evidence checked:

- `/auth/login` returns JWT-shaped access tokens with expiry, role, user id, and home id.
- Invalid and expired bearer tokens return `401`.
- Unauthenticated device command requests return `401`.
- `viewer` device command requests return `403`.
- `operator` device command requests succeed where allowed.
- `operator` permit-join requests return `403`.
- `admin` permit-join requests succeed.
- `docs/production/production-auth.md` records deferred refresh, `/auth/me`, and token-revocation items.

## Phase 3 Verification

Command:

```text
python -m pytest cloud/tests/test_production_mqtt_contract.py -q
```

Result:

```text
3 passed in 0.06s
docker compose config PASS
```

Evidence checked:

- Secure production compose mounts `mqtt/config/mosquitto.prod.conf`.
- Secure production compose mounts `mqtt/config/acl.prod.conf`.
- Secure production compose mounts `${MQTT_CERT_DIR:-../mqtt/certs}` read-only.
- Secure production compose exposes internal MQTT `8883`, not `1883`.
- Production Mosquitto config requires TLS/mTLS on `8883`.
- Production Mosquitto config has no `1883` or `9001` listener.
- Production ACL scopes `cloud`, `gateway`, and `monitor` without broad readwrite wildcard grants.
- Real certificates and private keys remain outside git.

## Phase 4 Verification

Command:

```text
python -m pytest cloud/tests/test_gateway_production_config_contract.py -q
```

Result:

```text
4 passed in 0.11s
```

Evidence checked:

- Gateway source has no demo public MQTT endpoint fallback.
- Gateway source has no demo MQTT password fallback.
- Production mode reads `SB_ENV=production` or `SB_PRODUCTION=1`.
- Production mode requires MQTT host, port, username, password, tenant/site/gateway id, CA cert, client cert, and client key.
- Gateway MQTT TLS setup calls `mosquitto_tls_set`.
- Tenant, site, and gateway id are runtime configurable.
- Bridge config templates use placeholders instead of real endpoints or passwords.

## Phase 5 Verification

Command:

```text
python -m pytest cloud/tests/test_secure_commissioning_contract.py -q
```

Result:

```text
4 passed
```

Evidence checked:

- Cloud commissioning duration remains bounded to `1..180` seconds.
- Gateway security config requires install-code joins and disables well-known key rejoins.
- Gateway command parser reads `target.eui64` and `target.install_code`.
- Gateway dispatch handles `gateway.prepare_join` with missing/bad input rejection.
- Gateway dispatch calls `netMgrOpenForJoinSecure` and clears the local install-code byte buffer.
- `docs/production/production-commissioning.md` documents the live negative procedure for default global key rejection.

## Phase 6 Verification

Command:

```text
python -m pytest cloud/tests/test_production_operations_contract.py -q
```

Result:

```text
3 passed
```

Evidence checked:

- `docs/production/production-operations.md` covers PostgreSQL backup/restore, Mosquitto persistence backup, gateway identity/cert backup, monitoring, alerting, and restore dry-run evidence.
- Secure compose persists `postgres-data`, `mosquitto-data`, and `mosquitto-log`.
- Secure compose retains healthchecks for PostgreSQL, MQTT, and API.
- Phase 6 checklist, final report, and progress dashboard link the operations runbook.
