# Security

The system controls physical devices, so security is not just login screens. The real boundary includes Cloud auth, user-to-device authorization, MQTT topic isolation, gateway credentials, Zigbee install codes, deployment secrets, and mobile transport.

## Current Security Model

| Boundary | Current model |
|---|---|
| Cloud REST API | Bearer-token auth through `cloud/app/auth.py`; user roles and home scope checks are used by control routes. |
| User roles | Admin, parent/operator, and viewer-style access are enforced through dependency functions and access-control helpers. |
| Mobile API access | Mobile attaches `Authorization: Bearer ...` when configured and release builds should reject unsafe remote HTTP. |
| MQTT transport | Production Mosquitto uses TLS, client certificates, password files, and ACLs. |
| MQTT namespace | Topics use `sb/v1/{tenant}/{site}/{gateway}`. This prefix is part of the authorization model. |
| Gateway | Production gateway config requires MQTT host, port, username, password, tenant, site, gateway id, and certificate paths. |
| Database | PostgreSQL stores users, password hashes, devices, commands, states, events, automations, factory devices, and provisioning sessions. |
| Provisioning | Factory devices and install codes gate device joins. Active provisioning sessions should be short-lived. |

## Known Risks

These are the durable conclusions carried forward from the removed security scan artifacts and checked against the current source shape.

### MQTT ACLs Are Still Too Broad

`mqtt/config/acl.prod.conf` uses wildcard tenant/site/gateway prefixes for Cloud, Gateway, and monitor identities. TLS and client certificates authenticate a client, but the ACL still allows broad topic access once the client is accepted. Narrow each MQTT identity to the tenant/site/gateway prefixes it actually owns.

### Deploy Examples Still Contain Demo Defaults

`deploy/.env.deploy.example` and deploy fallback logic include demo values such as `gateway123`, `cloud123`, `client123`, `monitor123`, `sb_user`, and `sb_pass`. The secure compose file is stricter, but operators can still copy weak defaults. Treat these as local examples only and rotate anything ever used on a reachable host.

### Provisioning Install Codes Need Tight Handling

`factory_devices` and `provisioning_sessions` store install-code material. That is sensitive because it can authorize a Zigbee join. Minimize retention, limit who can read or create labels, avoid logging install codes, and clear or mask stale values when the product no longer needs them.

### Local Secret Files Are Not Documentation

Private keys and PEM files may exist locally as untracked files during deployment work. They must stay untracked and should not be copied into docs, reports, design folders, or PR artifacts. `2110.pem` is intentionally out of scope for docs cleanup.

### Command And Object Scope Must Stay Tested

Current command and provisioning routes use user dependencies and object visibility helpers. Keep regression tests around home/device scope because command IDs, gateway commands, and provisioning sessions are high-impact paths.

### Non-Release Mobile Builds Can Still Be Risky

Release builds should enforce HTTPS and safer runtime config. Debug/profile builds can be configured for local HTTP, but if they talk to a real remote API with bearer tokens, traffic can be exposed on the network. Use local HTTP only for local development.

## Hardening Checklist

- Bind MQTT ACLs to exact tenant/site/gateway prefixes per identity.
- Use unique MQTT passwords per role and per deployed site.
- Rotate all demo passwords before exposing EC2, MQTT, or Cloud to the internet.
- Keep Mosquitto TLS and mTLS enabled in production.
- Keep `/health` public, but protect control, provisioning, automation, event, and inventory APIs.
- Keep command creation and command read paths scoped to the user's home.
- Keep provisioning labels admin-only.
- Redact install codes from logs, reports, and UI text unless there is a specific operational need.
- Prefer the secure production compose file for non-demo deployments.
- Store production auth secrets in deploy environment files or a secrets manager, not in Git.
- Keep `.env.deploy`, MQTT password files, generated certificates, PEM keys, and private keys out of commits.
- Run focused tests after any auth, MQTT, provisioning, or command-scope change.

## Post-Scan Action Items

1. Replace wildcard MQTT production ACLs with per-identity topic rules.
2. Remove weak deploy fallback credentials or make deploy fail closed when production secrets are missing.
3. Decide retention rules for install codes in `factory_devices` and `provisioning_sessions`.
4. Add or keep tests for command object scope, gateway command scope, automation action-device scope, and provisioning visibility.
5. Keep mobile release transport tests around `API_BASE_URL`, `API_AUTH_TOKEN`, and insecure remote HTTP rejection.
6. Review EC2 security groups and Nginx exposure before marking a deployment production-ready.

## Verification Commands

Docs-only changes do not need runtime tests. Security-sensitive code changes usually should run:

```powershell
python -m pytest cloud/tests -q
flutter test
flutter analyze
python -m compileall cloud/app
git diff --check
```
