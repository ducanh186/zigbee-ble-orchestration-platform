# Production Operations Runbook

Last updated: 2026-06-01 03:58:00 +07:00

Jira: SCRUM-98

Status: VERIFIED_LOCALLY

## Scope

This runbook documents backup, restore, monitoring, and alerting for the secure production compose path. It is intentionally operator-driven: it records commands, data ownership, and evidence requirements without embedding real hosts, passwords, certificates, or private keys.

## State Inventory

| Component | Production state | Backup scope | Restore target |
|---|---|---|---|
| PostgreSQL | `postgres-data:/var/lib/postgresql/data` | Logical dump from `pg_dump` plus schema/migration version. | Fresh PostgreSQL service with `pg_restore` or `psql` replay. |
| Mosquitto persistence | `mosquitto-data:/mosquitto/data` | Broker persistence files and retained message state when persistence is enabled. | `mosquitto-data` volume before broker start. |
| Mosquitto logs | `mosquitto-log:/mosquitto/log` | Operational logs for incident review and alert evidence. | Log archive only; do not restore as runtime state. |
| MQTT credentials | `../mqtt/passwords` | Password file and user inventory. | Same path on the target host with restricted permissions. |
| TLS certificates | `MQTT_CERT_DIR`, `NGINX_CERT_DIR` | CA, server certs, client certs, and expiry metadata. | Mounted cert directories on the target host. |
| Gateway identity | `SB_TENANT_ID`, `SB_SITE_ID`, `SB_GATEWAY_ID`, client certificate identity | gateway identity mapping and certificate serial/fingerprint. | Gateway production environment and certificate bundle. |

## Backup Procedure

Run these commands from the `deploy/` directory on the production host after confirming `.env.prod` points at the intended environment.

```powershell
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml ps
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml exec -T postgres pg_isready -U $env:POSTGRES_USER -d $env:POSTGRES_DB
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml exec -T postgres pg_dump -U $env:POSTGRES_USER -d $env:POSTGRES_DB -Fc > postgres.dump
docker run --rm -v sb_mosquitto-data:/data:ro -v ${PWD}:/backup alpine tar czf /backup/mosquitto-data.tgz -C /data .
docker run --rm -v sb_mosquitto-log:/logs:ro -v ${PWD}:/backup alpine tar czf /backup/mosquitto-log.tgz -C /logs .
```

Also copy these operator-managed files into the same encrypted backup bundle:

- `.env.prod` with secrets handled according to the operator secret-storage policy.
- `../mqtt/passwords`.
- `MQTT_CERT_DIR`.
- `NGINX_CERT_DIR`.
- Gateway production environment file and gateway identity mapping.

Do not commit backup artifacts to git.

## Restore Procedure

Restore to a new host or clean volume first. Do not overwrite a running production system until the dry-run succeeds.

```powershell
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml down
docker volume create sb_postgres-data
docker volume create sb_mosquitto-data
docker run --rm -v sb_mosquitto-data:/data -v ${PWD}:/backup alpine sh -c "cd /data && tar xzf /backup/mosquitto-data.tgz"
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml up -d postgres mosquitto
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml exec -T postgres pg_isready -U $env:POSTGRES_USER -d $env:POSTGRES_DB
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml exec -T postgres pg_restore -U $env:POSTGRES_USER -d $env:POSTGRES_DB --clean --if-exists < postgres.dump
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml up -d
```

If the dump was made as plain SQL instead of custom format, use `psql` rather than `pg_restore`.

## Restore Dry-Run Evidence

Local CI cannot prove a real production restore because production volumes, certificates, and secrets are intentionally absent. Before final readiness, record this restore dry-run evidence from an operator-approved environment:

1. Timestamped backup command output.
2. SHA256 checksums of `postgres.dump`, `mosquitto-data.tgz`, and certificate bundle inventory.
3. Restore dry-run target host or isolated volume name.
4. `pg_isready` success after restore.
5. API `/health` success after full stack start.
6. MQTT `mosquitto_sub` monitor command success against `$SYS/broker/uptime`.

## Monitoring Checks

| Check | Command or source | Healthy signal | Alert when |
|---|---|---|---|
| API health | `GET /health` through Nginx and internal cloud healthcheck. | HTTP 200. | Two consecutive failures or latency above operator threshold. |
| PostgreSQL | `pg_isready -U $POSTGRES_USER -d $POSTGRES_DB`. | Exit code 0. | One failure after retry window. |
| MQTT broker | `mosquitto_sub` with monitor client certificate on `$SYS/broker/uptime`. | One retained uptime message within 3 seconds. | TLS failure, auth failure, or timeout. |
| Gateway liveness | Gateway heartbeat/reported-state topic for the configured gateway identity. | Heartbeat inside expected interval. | Missing heartbeat for more than the operator SLA. |
| Disk/storage | Host disk usage and Docker volume usage for `postgres-data`, `mosquitto-data`, `mosquitto-log`. | Usage below threshold. | Above 80 percent warning or 90 percent critical unless operator chooses other limits. |
| Certificate expiry | Certificate inventory under `MQTT_CERT_DIR` and `NGINX_CERT_DIR`. | More than 30 days remaining. | 30-day warning, 7-day critical. |

## Alerting Contract

Operator must fill these values before production readiness:

| Field | Required value |
|---|---|
| alert channel | Slack, email, phone, or incident system URL. |
| escalation owner | Primary operator responsible for first response. |
| backup owner | Person responsible for scheduled backup verification. |
| restore approver | Person who can approve destructive restore on production. |
| evidence storage | Encrypted path or system where backup/restore logs are retained. |

## Local Verification

Command:

```text
python -m pytest cloud/tests/test_production_operations_contract.py -q
```

Expected result after Phase 6 implementation:

```text
3 passed
```

Full cloud regression should also pass:

```text
python -m pytest cloud/tests -q
```
