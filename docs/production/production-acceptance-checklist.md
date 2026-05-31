# Production Acceptance Checklist

Last updated: 2026-06-01 02:12:02 +07:00

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

- [ ] Public `80` redirects to `443`.
- [ ] Public `443` terminates HTTPS for `<PROD_DOMAIN>`.
- [ ] FastAPI is not directly public.
- [ ] PostgreSQL is private/internal only.
- [ ] Plain MQTT `1883` is not public.
- [ ] EC2 security group rules are documented.

Status: Not started.

## Phase 2 - REST API Authentication and Authorization

- [ ] Real login endpoint exists.
- [ ] Password hashing is implemented with a safe algorithm.
- [ ] JWT access tokens are issued and validated.
- [ ] Refresh/logout/me behavior is implemented or explicitly deferred with rationale.
- [ ] High-risk endpoints require authentication.
- [ ] Role-based access control covers `viewer`, `operator`, and `admin`.
- [ ] Unauthenticated command request returns `401`.
- [ ] Viewer command request returns `403`.
- [ ] Operator command request succeeds where allowed.
- [ ] Operator permit-join request returns `403`.
- [ ] Admin permit-join request succeeds.
- [ ] Invalid token returns `401`.
- [ ] Expired token returns `401`.

Status: Not started. `SCRUM-91` is delegated for mobile login-state work.

## Phase 3 - MQTT TLS/mTLS and Broker ACL Hardening

- [ ] Mosquitto production listener uses TLS/mTLS on `8883`.
- [ ] Plain `1883` is disabled in production or internal-only.
- [ ] Strict ACL is documented and tested.
- [ ] Certificate generation and rotation are documented.
- [ ] Connect without certificate fails.
- [ ] Unauthorized publish fails.
- [ ] Wrong client certificate fails.

Status: Not started.

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

