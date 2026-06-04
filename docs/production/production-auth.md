# Production REST API Auth Evidence

Scope: SCRUM-94 follow-up, Cloud-App REST API authentication/authorization and Mobile release guard.

## Status

Cloud-App REST auth/RBAC and Mobile release configuration guards are locally verified. This does not claim full production readiness; live environment validation remains pending.

## Endpoint Contract

| Endpoint | Production rule | Verification |
|---|---|---|
| `POST /auth/login` | Username/password login returns an access token, user id, role, home id, and expiry. | `cloud/tests/test_auth_rbac.py` |
| `POST /auth/logout` | Stateless logout returns `204`; token revocation is deferred. | Existing route contract |
| `POST /api/devices/{device_id}/command` | Requires `parent` or `admin`; rejects unauthenticated and `viewer`; parent can command only devices in the same home. | `cloud/tests/test_commands.py`, `cloud/tests/test_security_hardening.py` |
| `GET /api/devices/`, `GET /api/devices/{device_id}`, `GET /api/devices/{device_id}/state` | Requires login; admin sees all, non-admin users see same-home devices plus the existing unassigned-device exception. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_devices.py` |
| `GET /api/events/` | Requires login; admin sees all, non-admin users see events for visible devices only. | `cloud/tests/test_security_hardening.py` |
| `GET /api/commands/{command_id}` | Requires login; device commands require visible-device access, while gateway-targeted command status requires `parent` or `admin`. | `cloud/tests/test_commands.py`, `cloud/tests/test_gateways.py` |
| `GET/POST/PUT/DELETE /api/automations...` | Requires login; `viewer` can read visible rules, while `parent` and `admin` can mutate rules when referenced devices are home-visible/manageable. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_automations.py` |
| `GET /api/automation-events` | Requires login; admin sees all, non-admin users see events for visible automation rules only. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_automation_events.py` |
| `POST/GET/DELETE /api/provisioning/sessions...` | Requires login for reads; create/cancel require `parent` or `admin` and are scoped to visible rooms/sessions. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_provisioning.py` |
| `DELETE /api/devices/{device_id}` | Requires `parent` or `admin`; parent can delete only devices in the same home. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_devices.py` |
| `POST /api/devices/{device_id}/rediscover` | Requires `parent` or `admin`; parent can rediscover only devices in the same home. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_gateways.py` |
| `POST /api/gateways/{gateway_id}/commissioning/open` | Requires `parent` or `admin`; v1 restricts the request to the configured gateway id and requires parent sessions to have `home_id`. | `cloud/tests/test_gateways.py` |
| `POST /api/gateways/{gateway_id}/commissioning/close` | Requires `parent` or `admin`; v1 restricts the request to the configured gateway id and requires parent sessions to have `home_id`. | `cloud/tests/test_gateways.py` |
| `POST /api/provisioning/labels` | Requires `admin`. | `cloud/tests/test_auth_rbac.py` |

## Role Contract

| Role | Meaning in this phase | Notes |
|---|---|---|
| `viewer` | Read-only member. | Can view device list, state, motion/event history, and visible automation/event records. |
| `parent` | Home owner role. | Can manage devices, commands, automations, provisioning, commissioning, rediscover, and delete inside the same `home_id`. |
| `admin` | Technical/system administrator. | Can manage all homes and use admin-only production/system endpoints. |

Legacy database values are normalized before they leave the API boundary:

| Legacy value | Canonical API role |
|---|---|
| `operator` | `parent` |
| `user` | `parent` |
| `member` | `viewer` |

Public login/session output must return only `admin`, `parent`, or `viewer`.

## Cloud DB Role Migration

Use this sequence before changing a live production database:

```text
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > backups/pre-rbac-role-migration.sql
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml exec -T postgres psql -U "$POSTGRES_USER" "$POSTGRES_DB" < database/migrations/20260602_canonical_user_roles.sql
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml restart cloud-api
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml exec -T postgres psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "select role, count(*) from users group by role order by role;"
```

Expected post-migration roles are `admin`, `parent`, and `viewer` only. The SQL file is idempotent and also updates the default role to `viewer`.

## Token Contract

- Access tokens use JWT shape with `HS256` signing and `typ=JWT`.
- Token payload includes `sub`, `role`, `home_id`, and `exp`.
- Invalid and expired tokens return `401`.
- Password hashes use PBKDF2-HMAC-SHA256 with per-password salt.
- Production auth secret canonical env is `SB_AUTH_TOKEN_SECRET`.
- `SB_JWT_SECRET` remains a compatibility alias so older deploy env files do not silently fall back to `dev-only-change-me`.

## Mobile Release Guard

- Release builds fail early unless `API_BASE_URL` is HTTPS.
- Release builds fail early when `HIDE_LOGIN=true`.
- Debug/demo builds can still use HTTP or login bypass through explicit compile flags.
- Existing token flow remains: login saves the secure token, and API requests attach `Authorization: Bearer ...`.

Deferred items:

- Refresh token flow is not implemented in this backend slice.
- `/auth/me` is not implemented in this backend slice.
- Server-side token revocation is not implemented because current tokens are stateless and short-lived.

## HTTPS Origin Certificate

`dashboard.iot-building.app` is served through the Cloudflare proxy. EC2 should
use a Cloudflare Origin CA certificate instead of the Let's Encrypt standalone
HTTP-01 flow.

Set `HTTPS_CERT_MODE=cloudflare-origin` in the ignored deploy config after
placing these remote-only files on EC2:

```text
deploy/nginx/certs/cloudflare-origin.pem
deploy/nginx/certs/cloudflare-origin.key
```

Then set Cloudflare SSL/TLS mode to `Full (strict)`.

## Verification

RED evidence before implementation:

```text
python -m pytest cloud/tests/test_auth_rbac.py cloud/tests/test_commands.py cloud/tests/test_gateways.py cloud/tests/test_security_hardening.py -q
20 failed, 14 passed
```

GREEN evidence after implementation:

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
