# v0.9.0-rc.1 Production hardening RC

Pre-release: production-hardening release candidate.

Not production ready.

## Included work

- PR #66: backend REST auth/RBAC hardening.
- PR #67: production MQTT TLS/mTLS and ACL contract.
- PR #68: gateway production config hardening.
- PR #69: secure Zigbee commissioning command path and evidence.
- PR #70: backup, restore, monitoring, and alerting operations runbook.
- PR #71: release, rollback, final evidence, and release candidate docs.

## Verification

- `python -m pytest cloud/tests -q`
- `git diff --check`
- `docker compose --env-file .env.prod -f docker-compose.prod-secure.yml config`

## EC2 deploy

EC2 deploy was completed from the merged Phase 6 code using `deploy/deploy.ps1`.

Verified after deploy:

- Cloud API `/health` returned status `ok`.
- `sb-cloud-api` was healthy.
- `sb-mosquitto` was healthy.
- `sb-postgres` was healthy.

## Known limitations

- Existing EC2 deploy script still uses legacy `docker-compose.prod.yml`.
- Secure compose cutover needs operator-approved certificate and environment setup.
- Live MQTT mTLS negative tests remain pending.
- Live gateway hardware startup remains pending.
- Zigbee default global key rejection needs hardware evidence.
- Real backup/restore dry-run evidence remains pending.
- Mobile login-state integration remains under `SCRUM-91`.
