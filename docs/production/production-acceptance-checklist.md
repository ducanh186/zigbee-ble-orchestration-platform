# Production Acceptance Checklist

Last updated: 2026-06-02 15:13:36 +07:00

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
- [x] Cloud-App read endpoints require authentication except `/health`, `/auth/login`, and `/auth/logout`.
- [x] Device, event, command, automation, automation-event, and provisioning session reads are scoped by `home_id` where applicable.
- [x] Automation and provisioning writes reject `viewer` and require `parent` or `admin` with same-home referenced devices/rooms.
- [x] Device delete and rediscover require `parent` or `admin`; parent is same-home scoped.
- [x] Mobile release builds fail early for non-HTTPS `API_BASE_URL` or `HIDE_LOGIN=true`.
- [x] Role-based access control covers `viewer`, `parent`, and `admin`.
- [x] Unauthenticated command request returns `401`.
- [x] Viewer command request returns `403`.
- [x] Parent command request succeeds where allowed.
- [x] Parent permit-join request succeeds for the configured gateway.
- [x] Admin permit-join request succeeds.
- [x] Invalid token returns `401`.
- [x] Expired token returns `401`.

Status: Cloud-App REST API slice and Mobile release guard verified locally. Live environment validation remains pending before production readiness.

Evidence:

```text
python -m pytest cloud/tests/test_auth_rbac.py cloud/tests/test_commands.py cloud/tests/test_devices.py cloud/tests/test_gateways.py cloud/tests/test_provisioning.py cloud/tests/test_automations.py cloud/tests/test_security_hardening.py cloud/tests/test_schemas.py -q
133 passed

flutter analyze
No issues found

flutter test
93 passed

flutter build apk --release --dart-define=API_BASE_URL=https://dashboard.iot-building.app --dart-define=USE_MOCK_API=false
Built build\app\outputs\flutter-apk\app-release.apk
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

- [x] Gateway production mode fails fast without MQTT host.
- [x] Gateway production mode fails fast without TLS certificate paths.
- [x] Dangerous fallback to public IP is removed or disabled in production.
- [x] Dangerous fallback credentials are removed or disabled in production.
- [x] Tenant, site, and gateway IDs are configurable.
- [x] Development mode can still use explicit localhost demo configuration.

Status: Verified locally by static gateway config contract tests. Live gateway hardware startup is not run in this environment.

Evidence:

```text
python -m pytest cloud/tests/test_gateway_production_config_contract.py -q
4 passed in 0.11s
```

Runbook: docs/production/production-gateway.md

## Phase 5 - Zigbee Secure Commissioning

- [x] Permit join is closed by default.
- [x] Permit join duration is short and bounded.
- [x] Only parent/admin sessions can open permit join.
- [x] Install-code commissioning support is proven or documented.
- [x] Default global Zigbee key join is rejected by gateway security config and marked for live negative evidence.
- [x] Negative commissioning procedure exists.

Status: Verified locally by secure commissioning contract tests. Live default global key rejection must still be captured on gateway hardware before final production readiness is claimed.

Evidence:

```text
python -m pytest cloud/tests/test_secure_commissioning_contract.py -q
4 passed
```

Runbook: docs/production/production-commissioning.md

## Phase 6 - Backup, Restore, Monitoring, and Alerting

- [x] PostgreSQL backup scope is documented.
- [x] Mosquitto persistence backup scope is documented.
- [x] Gateway identity/certificate backup scope is documented.
- [x] Restore procedure is documented.
- [x] Health monitoring is documented.
- [x] Alerting channel is documented.
- [x] Backup/restore dry-run evidence exists or is marked not testable here.

Status: Verified locally by operations contract tests. Real backup and restore dry-run evidence must still be captured in an operator-approved environment before final production readiness is claimed.

Evidence:

```text
python -m pytest cloud/tests/test_production_operations_contract.py -q
3 passed
```

Runbook: docs/production/production-operations.md

## Phase 7 - CI/CD, Release, Rollback, and Final Evidence

- [x] CI commands are documented.
- [x] Release steps are documented.
- [x] Rollback procedure is documented.
- [x] Final report links all evidence.
- [x] All checklist items are complete or explicitly accepted as deferred by live validation items.

Status: Release candidate evidence verified locally. The platform remains not production ready until the deferred live validation items are completed.

Evidence:

```text
python -m pytest cloud/tests/test_release_readiness_contract.py -q
3 passed
```

Runbook: docs/production/production-release.md
Release notes: docs/production/release-notes-v0.9.0-rc.1.md
