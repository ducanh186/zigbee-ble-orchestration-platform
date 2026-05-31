# Production Security Audit

Last updated: 2026-06-01 02:12:02 +07:00

Jira: SCRUM-90

Status: AUDITING

This audit records the current repository and deployment assumptions for the Zigbee Smart Building Platform. It does not claim production readiness. Each finding is backed by repository evidence or marked as `Needs confirmation`.

## Scope

Architecture under review:

```text
Flutter Mobile App
  -> FastAPI Cloud REST API
  -> Mosquitto MQTT Broker
  -> Native Silicon Labs Z3Gateway C host app
  -> EFR32 NCP
  -> Zigbee end devices
```

Production target:

```text
Mobile App
  -> HTTPS + real authentication
  -> Nginx / reverse proxy
  -> FastAPI Cloud API, not directly public
  -> PostgreSQL private/internal only

Cloud API
  -> MQTT over TLS/mTLS
  -> Mosquitto with strict ACL
  -> Z3Gateway with per-gateway credential/certificate

Gateway
  -> Zigbee secure commissioning
  -> Permit join closed by default
  -> Install-code-based join
  -> Default global Zigbee key rejected
```

## Executive Summary

Current evidence shows the repository is still closer to a demo or lab deployment than a production deployment:

- FastAPI is configured to bind to `0.0.0.0:8000` in current defaults and Docker startup.
- Existing EC2 deployment docs and scripts expose API `8000`, MQTT `1883`, and PostgreSQL `5432`.
- Mosquitto currently has a plain listener on `1883` and no production TLS/mTLS listener in the checked configuration.
- Backend API routing currently registers domain routers directly, and no backend auth router was found in the Phase 0 evidence scan.
- Mobile app defaults point to a plain HTTP demo API URL and do not yet prove HTTPS-only production auth.
- Gateway commissioning API exposes permit-join operations, but production authorization and secure commissioning guarantees need further implementation and test evidence.
- Backup, monitoring, alerting, and rollback are partially documented through logs/healthcheck notes, but no production-grade backup/restore/alerting runbook is present in `docs/production/`.

## Evidence Table

| Area | Current evidence | Risk | Status |
|---|---|---|---|
| Production docs | `docs/production` was missing before Phase 0. | No single production source of truth. | Phase 0 creates it. |
| Cloud config defaults | `cloud/app/config.py:9-18` contains default DB URL, MQTT host/port/user/password, API host, and API port. Secret-like values are redacted in this report. | Demo defaults can leak into deployment if not overridden. | Needs hardening. |
| API bind | `cloud/app/config.py:17-18`; `cloud/Dockerfile:18,21` bind/expose API on `0.0.0.0:8000`. | Direct public API exposure. | Needs Nginx/private binding phase. |
| EC2 docs | `cloud/README.md:79,108-110`; `deploy/ec2-setup.sh:66-69` document public `8000` and `1883`. | Public attack surface for REST and MQTT. | Needs doc and deploy correction. |
| Docker Compose ports | `deploy/docker-compose.prod.yml:6-7,30-31,47-48` maps `1883`, `5432`, and `8000` to host ports. | MQTT, DB, and API can become public depending on host firewall/security group. | Needs production compose profile. |
| MQTT listener | `mqtt/config/mosquitto.prod.conf` defines production listener `8883` with TLS/mTLS, while local dev `mqtt/config/mosquitto.conf` still keeps `1883` and `9001` for development. | Live broker negative tests still need operator-approved certificates/environment. | Production config verified locally in Phase 3. |
| MQTT credentials | Gateway source now requires explicit production MQTT username/password and cert paths when `SB_ENV=production` or `SB_PRODUCTION=1`; bridge configs use placeholders only. | Legacy deploy scripts still need release-path cleanup before final production rollout. | Gateway Phase 4 verified locally; deploy cleanup remains Phase 7. |
| Mobile API base URL | `mobile_app/lib/main.dart:17-20`; `mobile_app/README.md:13,24` show HTTP API base URL defaults/examples. | Mobile production can target plain HTTP. | Needs Phase 1/2 mobile alignment. |
| Backend auth routes | `cloud/app/routers/auth.py` implements login/logout, `cloud/app/auth.py` validates JWT-shaped bearer tokens, and `cloud/tests/test_auth_rbac.py` covers login, invalid token, and expired token behavior. | Mobile login-state integration is still pending under `SCRUM-91`. | Backend Phase 2 verified locally. |
| Permit join API | `cloud/app/routers/gateways.py` protects open/close commissioning with `require_admin`, and `cloud/tests/test_gateways.py` covers unauthenticated, operator-forbidden, and admin-allowed behavior. | Secure Zigbee install-code/default-key guarantees still need Phase 5 evidence. | Backend auth done; secure commissioning needs Phase 5. |
| Nginx/reverse proxy | `docs/production`, `deploy/.env.prod.example`, `nginx`, and `deploy/nginx.conf` were missing in Phase 0 scan. | HTTPS reverse proxy contract not documented or implemented. | Needs Phase 1. |
| Backup/monitoring/rollback | `cloud/README.md:101-102,138`; `mqtt/README.md:68-69` mention logs and monitor user. | Not enough for production recovery or alerting. | Needs Phase 6/7. |

## Current Exposure Map

| Component | Current repo signal | Production target | Gap |
|---|---|---|---|
| Mobile app | HTTP API base URL defaults/examples exist. | HTTPS only via `<PROD_DOMAIN>`. | Needs production runtime config and auth token flow. |
| Nginx | No production Nginx config found in Phase 0 scan. | Public `80/443`; redirect HTTP to HTTPS. | Needs Phase 1. |
| FastAPI | Exposes/binds `8000`. | Internal only behind Nginx. | Needs Phase 1. |
| PostgreSQL | Compose maps `5432:5432`. | Private/internal only. | Needs Phase 1/6. |
| Mosquitto | Secure compose uses `mqtt/config/mosquitto.prod.conf`, `mqtt/config/acl.prod.conf`, and cert mount `${MQTT_CERT_DIR:-../mqtt/certs}`. | TLS/mTLS on `8883`, strict ACL, no public plain MQTT. | Phase 3 locally verified; live negative tests pending. |
| Gateway | `gateway/Z3GatewayHost/app/app_mqtt.c` has production fail-fast config and runtime tenant/site/gateway identity; bridge configs no longer commit real endpoint/password values. | Live gateway hardware startup still needs operator validation. | Phase 4 locally verified; secure commissioning needs Phase 5. |

## Items Needing Human Confirmation

- `<PROD_DOMAIN>` and certificate provider.
- EC2 security group policy owner and whether direct SSH-only operations are acceptable.
- Whether production will use one gateway certificate per physical gateway.
- Whether mobile refresh-token backend endpoints already exist on another branch.
- Required backup retention period and restore time objective.
- Required alerting channel, for example email, Slack, CloudWatch alarm, or another service.
