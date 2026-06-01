# Production Networking Runbook

Last updated: 2026-06-01 02:24:00 +07:00

Jira: SCRUM-93

Status: PHASE_1_VERIFIED

## Goal

Production traffic must enter through HTTPS on Nginx. FastAPI, PostgreSQL, and plain MQTT must not be directly public.

## Public Inbound Rules

| Port | Source | Purpose | Status |
|---|---|---|---|
| 22 | Operator IP only | SSH administration | Needs operator confirmation |
| 80 | Internet | HTTP to HTTPS redirect and ACME challenge path | Documented in `deploy/nginx/prod.conf` |
| 443 | Internet | HTTPS application traffic | Documented in `deploy/nginx/prod.conf` |

## Not Public

| Port | Component | Production intent | Evidence |
|---|---|---|---|
| 8000 | FastAPI | Internal Docker network only, reached through Nginx | `deploy/docker-compose.prod-secure.yml` uses `expose: "8000"` |
| 5432 | PostgreSQL | Internal Docker network only | `deploy/docker-compose.prod-secure.yml` uses `expose: "5432"` |
| 1883 | Plain MQTT | Internal only until MQTT TLS/mTLS Phase 3 | `deploy/docker-compose.prod-secure.yml` has no host port mapping for `1883` |

## Secure Compose Command

Run from the `deploy/` directory on the production host after creating a private `.env.prod` file outside git:

```powershell
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml up -d
```

Linux shell equivalent:

```sh
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml up -d
```

## Certificate Contract

Nginx expects certificate files mounted read-only at:

```text
/etc/nginx/certs/fullchain.pem
/etc/nginx/certs/privkey.pem
```

The host-side directory is configured with:

```text
NGINX_CERT_DIR=./nginx/certs
```

The repository tracks only `deploy/nginx/certs/.gitignore`. Do not commit certificate public certificates or private keys.

## Current Limitations

- Phase 1 does not implement MQTT TLS/mTLS; that is Phase 3.
- Phase 1 does not implement backend authentication; that is Phase 2.
- Live EC2 security group state is not testable in this local environment.
