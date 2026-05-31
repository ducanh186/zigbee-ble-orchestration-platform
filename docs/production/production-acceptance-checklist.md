# Production Acceptance Checklist

Last updated: 2026-06-01 03:05:25 +07:00

Jira: SCRUM-90

Status: NOT_READY

Do not mark production ready until every required item is checked with evidence.

## Phase 0 - Scope and Evidence Contract

- [x] `docs/production/production-security-audit.md` exists.
- [x] `docs/production/production-hardening-plan.md` exists.
- [x] `docs/production/production-acceptance-checklist.md` exists.
- [x] `docs/production/production-progress.html` exists.
- [x] `docs/production/production-final-report.md` exists.
- [x] `deploy/.env.prod.example` exists.
- [x] Production docs use placeholders instead of real secrets.
- [x] Current audit records evidence or `Needs confirmation` notes.

Evidence:

```text
Worktree: C:\tmp\zigbee-scrum90-production-hardening
Branch: codex/scrum-90-production-hardening
Phase 0 timestamp: 2026-06-01 02:12:02 +07:00
```

## Phase 1 - Public Exposure Lockdown and HTTPS Reverse Proxy

- [x] Public `80` redirects to `443`.
- [x] Public `443` terminates HTTPS for `<PROD_DOMAIN>`.
- [x] FastAPI is not directly public in the secure production compose file.
- [x] PostgreSQL is private/internal only in the secure production compose file.
- [x] Plain MQTT `1883` is not public in the secure production compose file.
- [x] EC2 security group rules are documented.

Evidence:

```text
Test: python -m pytest cloud/tests/test_production_exposure_contract.py -q
Result: 2 passed in 0.06s
Compose: docker compose --env-file .env.prod -f docker-compose.prod-secure.yml config
Compose result: PASS
Config: deploy/docker-compose.prod-secure.yml
Config: deploy/nginx/prod.conf
Runbook: docs/production/production-networking.md
```

Status: Verified locally. Live EC2 security group state is not testable in this environment.

## Phase 2 - REST API Authentication and Authorization

- [x] Real login endpoint exists.
- [x] Password hashing is implemented with a safe algorithm.
- [x] JWT access tokens are issued and validated.
- [x] Refresh/logout/me behavior is implemented or explicitly deferred with rationale.
- [x] Phase 2 high-risk actuator endpoints require authentication.
- [x] Role-based access control covers `viewer`, `operator`, and `admin`.
- [x] Unauthenticated command request returns `401`.
- [x] Viewer command request returns `403`.
- [x] Operator command request succeeds where allowed.
- [x] Operator permit-join request returns `403`.
- [x] Admin permit-join request succeeds.
- [x] Invalid token returns `401`.
- [x] Expired token returns `401`.

Status: Backend REST API slice verified locally. Mobile login-state work remains delegated under `SCRUM-91`.

Evidence:

```text
python -m pytest cloud/tests/test_auth_rbac.py cloud/tests/test_commands.py cloud/tests/test_gateways.py -q
23 passed in 9.54s
```

Runbook: docs/production/production-auth.md

## Phase 3 - MQTT TLS/mTLS and Broker ACL Hardening

- [x] Mosquitto production listener uses TLS/mTLS on `8883`.
- [x] Plain `1883` is disabled in production or internal-only.
- [x] Strict ACL is documented and tested.
- [x] Certificate layout and rotation boundary are documented.
- [x] Connect without certificate is configured to fail through `require_certificate true`.
- [x] Unauthorized publish is configured to fail through `acl.prod.conf`.
- [x] Wrong client certificate is configured to fail through production CA trust.

Status: Verified locally by static contract tests and Docker Compose config parsing. Live broker negative tests are documented but not run in this environment.

Evidence:

```text
python -m pytest cloud/tests/test_production_mqtt_contract.py -q
3 passed in 0.06s
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml config
PASS
```

Runbook: docs/production/production-mqtt.md

## Phase 4 - Gateway Config Hardening and Secret Removal

- [ ] Gateway production mode fails fast without MQTT host.
- [ ] Gateway production mode fails fast without TLS certificate paths.
- [ ] Dangerous fallback to public IP is removed or disabled in production.
- [ ] Dangerous fallback credentials are removed or disabled in production.
- [ ] Tenant, site, and gateway IDs are configurable.
- [ ] Development mode can still use explicit localhost demo configuration.

Status: Not started.

## Phase 5 - Zigbee Secure Commissioning

- [ ] Permit join is closed by default.
- [ ] Permit join duration is short and bounded.
- [ ] Only admin can open permit join.
- [ ] Install-code commissioning support is proven or documented.
- [ ] Default global Zigbee key join is rejected or documented as `Needs confirmation`.
- [ ] Negative commissioning procedure exists.

Status: Not started.

## Phase 6 - Backup, Restore, Monitoring, and Alerting

- [ ] PostgreSQL backup scope is documented.
- [ ] Mosquitto persistence backup scope is documented.
- [ ] Gateway identity/certificate backup scope is documented.
- [ ] Restore procedure is documented.
- [ ] Health monitoring is documented.
- [ ] Alerting channel is documented.
- [ ] Backup/restore dry-run evidence exists or is marked not testable here.

Status: Not started.

## Phase 7 - CI/CD, Release, Rollback, and Final Evidence

- [ ] CI commands are documented.
- [ ] Release steps are documented.
- [ ] Rollback procedure is documented.
- [ ] Final report links all evidence.
- [ ] All checklist items are complete or explicitly accepted as deferred by the operator.

Status: Not started.
