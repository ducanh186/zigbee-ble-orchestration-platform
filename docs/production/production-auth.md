# Production REST API Auth Evidence

Scope: SCRUM-94, Phase 2 backend REST API authentication and authorization.

## Status

Backend REST auth/RBAC is locally verified for the high-risk actuator endpoints in this phase. Full production readiness still depends on mobile login-state integration under `SCRUM-91` and later live environment validation.

## Endpoint Contract

| Endpoint | Production rule | Verification |
|---|---|---|
| `POST /auth/login` | Username/password login returns an access token, user id, role, home id, and expiry. | `cloud/tests/test_auth_rbac.py` |
| `POST /auth/logout` | Stateless logout returns `204`; token revocation is deferred. | Existing route contract |
| `POST /api/devices/{device_id}/command` | Requires `operator`, legacy `user`, or `admin`; rejects unauthenticated and `viewer`. | `cloud/tests/test_commands.py` |
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
python -m pytest cloud/tests/test_auth_rbac.py cloud/tests/test_commands.py cloud/tests/test_gateways.py -q
23 passed in 9.54s
```
