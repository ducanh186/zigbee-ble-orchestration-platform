# Security

The system controls physical devices, so security is not just login screens. The real boundary includes Cloud auth, user-to-device authorization, MQTT topic isolation, gateway credentials, Zigbee install codes, deployment secrets, and mobile transport.

## Current Security Model

| Boundary | Current model |
|---|---|
| Cloud REST API | Bearer-token auth through `cloud/app/auth.py`; user roles and home scope checks are used by control routes. |
| User roles | Admin, parent/operator, and viewer-style access are enforced through dependency functions and access-control helpers. |
| Mobile API access | Mobile attaches `Authorization: Bearer ...` when configured and release builds should reject unsafe remote HTTP. |
| MQTT transport | Production Mosquitto uses TLS 1.2+, required client certificates, certificate common names as identities, and generated ACLs. |
| MQTT namespace | Topics use `sb/v1/{tenant}/{site}/{gateway}`. Each Gateway certificate is bound to one exact namespace tuple. |
| Gateway | The production target requires MQTT host, port, TLS/mTLS paths, principal id, tenant, site, and gateway id. Username/password remains local-development only. |
| Database | PostgreSQL stores users, password hashes, devices, commands, states, events, automations, factory devices, and provisioning sessions. |
| Provisioning | Factory devices and install codes gate device joins. Active provisioning sessions should be short-lived. |

## Known Risks

These are the durable conclusions carried forward from the removed security scan artifacts and checked against the current source shape.

### Gateway Cutover Is Not Complete Yet

Broker and Cloud configuration support certificate identity, but Gateway C changes are intentionally outside this branch. Do not switch the production broker until Gateway owners confirm that each Gateway keeps its private key locally, uses a CSR common name equal to its inventory `principal_id`, no longer requires username/password in certificate mode, and uses a unique client id derived from the principal.

### Deploy Examples Still Contain Demo Defaults

Database examples still contain local demo values such as `sb_user` and `sb_pass`. The secure compose file is stricter, but operators can still copy weak defaults. Treat these as local examples only and rotate anything ever used on a reachable host.

### Provisioning Install Codes Need Tight Handling

QR payloads do not carry install codes. Cloud resolves the factory device record, sends the install code to Gateway in `gateway.prepare_join`, and Gateway opens a short secure join window for that EUI64. `factory_devices` and `provisioning_sessions` store install-code material, which is sensitive because it can authorize a Zigbee join. Minimize retention, limit who can create labels or sessions, avoid logging install codes, and clear or mask stale values when the product no longer needs them.

The expected negative evidence is that joins do not fall back to the Zigbee default global key. Gateway security config requires install-code joins and disables well-known-key rejoins.

### Local Secret Files Are Not Documentation

Private keys and PEM files may exist locally as untracked files during deployment work. They must stay untracked and should not be copied into docs, reports, design folders, or PR artifacts. `2110.pem` is intentionally out of scope for docs cleanup.

### Command And Object Scope Must Stay Tested

Current command and provisioning routes use user dependencies and object visibility helpers. Keep regression tests around home/device scope because command IDs, gateway commands, and provisioning sessions are high-impact paths.

### Non-Release Mobile Builds Can Still Be Risky

Release builds should enforce HTTPS and safer runtime config. Debug/profile builds can be configured for local HTTP, but if they talk to a real remote API with bearer tokens, traffic can be exposed on the network. Use local HTTP only for local development.

## Hardening Checklist

- Keep the real MQTT Gateway inventory and all generated PKI material out of Git.
- Require unique certificate principals and exact tenant/site/gateway tuples.
- Generate each Gateway private key on that Gateway and transfer only its CSR.
- Keep the CA private key outside containers and restrict it to mode `0600`.
- Keep Mosquitto TLS and mTLS enabled in production.
- Keep `/health` public, but protect control, provisioning, automation, event, and inventory APIs.
- Keep command creation and command read paths scoped to the user's home.
- Keep provisioning labels admin-only.
- Redact install codes from logs, reports, and UI text unless there is a specific operational need.
- Prefer the secure production compose file for non-demo deployments.
- Store production auth secrets in deploy environment files or a secrets manager, not in Git.
- Keep `.env.deploy`, the real MQTT inventory, CSRs, generated ACLs, certificates, PEM keys, and private keys out of commits.
- Run focused tests after any auth, MQTT, provisioning, or command-scope change.

## Post-Scan Action Items

1. Complete and verify the Gateway certificate-identity changes before broker cutover.
2. Decide retention rules for install codes in `factory_devices` and `provisioning_sessions`.
3. Add or keep tests for command object scope, gateway command scope, automation action-device scope, and provisioning visibility.
4. Keep mobile release transport tests around `API_BASE_URL`, `API_AUTH_TOKEN`, and insecure remote HTTP rejection.
5. Review EC2 security groups and Nginx exposure before marking a deployment production-ready.

## Verification Commands

Docs-only changes do not need runtime tests. Security-sensitive code changes usually should run:

```powershell
python -m pytest cloud/tests -q
flutter test
flutter analyze
python -m compileall cloud/app
git diff --check
```
