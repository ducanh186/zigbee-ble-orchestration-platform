# Production REST API Auth Evidence

Scope: SCRUM-94 follow-up, Cloud-App REST API authentication/authorization and Mobile release guard.

## Status

Cloud-App REST auth/RBAC and Mobile release configuration guards are locally verified. This does not claim full production readiness; live environment/operator validation remains pending.

## Endpoint Contract

| Endpoint | Production rule | Verification |
|---|---|---|
| `POST /auth/login` | Username/password login returns an access token, user id, role, home id, and expiry. | `cloud/tests/test_auth_rbac.py` |
| `POST /auth/logout` | Stateless logout returns `204`; token revocation is deferred. | Existing route contract |
| `POST /api/devices/{device_id}/command` | Requires `operator`, legacy `user`, or `admin`; rejects unauthenticated and `viewer`. | `cloud/tests/test_commands.py` |
| `GET /api/devices/`, `GET /api/devices/{device_id}`, `GET /api/devices/{device_id}/state` | Requires login; admin sees all, non-admin users see same-home devices plus the existing unassigned-device exception. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_devices.py` |
| `GET /api/events/` | Requires login; admin sees all, non-admin users see events for visible devices only. | `cloud/tests/test_security_hardening.py` |
| `GET /api/commands/{command_id}` | Requires login; gateway-targeted commands are admin-only, device commands require visible-device access. | `cloud/tests/test_commands.py`, `cloud/tests/test_gateways.py` |
| `GET/POST/PUT/DELETE /api/automations...` | Requires login; `viewer` can read visible rules, `operator`/legacy `user`/`admin` can mutate rules when referenced devices are visible. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_automations.py` |
| `GET /api/automation-events` | Requires login; admin sees all, non-admin users see events for visible automation rules only. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_automation_events.py` |
| `POST/GET/DELETE /api/provisioning/sessions...` | Requires login; `operator`/legacy `user`/`admin` can create/cancel sessions only for visible rooms/sessions. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_provisioning.py` |
| `DELETE /api/devices/{device_id}` | Requires `admin`. | `cloud/tests/test_security_hardening.py`, `cloud/tests/test_devices.py` |
| `POST /api/devices/{device_id}/rediscover` | Requires `admin`. | `cloud/tests/test_security_hardening.py` |
| `POST /api/gateways/{gateway_id}/commissioning/open` | Requires `admin`; rejects unauthenticated and `operator`. | `cloud/tests/test_gateways.py` |
| `POST /api/gateways/{gateway_id}/commissioning/close` | Requires `admin`. | `cloud/tests/test_gateways.py` |
| `POST /api/provisioning/labels` | Requires `admin`. | `cloud/tests/test_auth_rbac.py` |

## Role Contract

| Role | Meaning in this phase | Notes |
|---|---|---|
| `viewer` | Read-oriented role. | Cannot submit device commands or open permit join. |
| `operator` | Can submit allowed device commands. | Cannot open or close permit join. |
| `admin` | Can run admin-only provisioning and commissioning actions. | Required for permit join. |
| `user` | Legacy operator-equivalent role retained for backward compatibility. | Should be normalized in a later migration if product roles are finalized. |

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

## Verification

RED evidence before implementation:

```text
python -m pytest cloud/tests/test_commands.py cloud/tests/test_gateways.py -q
2 failed, 15 passed
```

GREEN evidence after implementation:

```text
python -m pytest cloud/tests -q
172 passed, 21 skipped

flutter test
93 passed
```
