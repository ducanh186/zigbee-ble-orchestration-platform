# Smart Home Account Center

Static web UI for checking cloud events, device state, device join windows,
provisioning labels, and command status during development.

## Canonical local dev flow (Linux)

Two long-lived processes, started independently so each can be restarted
without taking the other down. This is the flow used on the dev box and what
the project's runbooks (`docs/instruct.md` §F-G) target.

```bash
cd ~/Desktop/Repos/zigbee-ble-orchestration-platform

# 1. Backend (FastAPI + Postgres + MQTT subscriber)
.venv/bin/python -m uvicorn cloud.app.main:app --host 0.0.0.0 --port 8000 \
  > /tmp/cloud.log 2>&1 &

# 2. UI dev server (proxies /api/* and /health to 127.0.0.1:8000)
PORT=5173 API_TARGET=http://127.0.0.1:8000 \
  python3 cloud/webdev/dev_server.py > /tmp/webdev.log 2>&1 &
```

Open:

```text
http://localhost:5173
```

The dev server proxies `/api/*` and `/health` to `http://127.0.0.1:8000`.
Override the backend target when pointing at a remote API:

```bash
API_TARGET="http://<ec2-public-ip>:8000" python3 cloud/webdev/dev_server.py
```

## Bundled launcher (alternative)

`start_dev.py` runs `cloud.app.seed` then spawns uvicorn + dev_server in one
process. Convenient for first-time setup, but the canonical flow above is
preferred for day-to-day use because:

- Each service has its own log file you can tail independently.
- Restarting one (e.g. uvicorn after a code edit) does not kill the other.
- `seed` re-runs every launch with the bundled launcher — under the
  manual flow you opt in by running `python3 -m cloud.app.seed` once.

```bash
python3 cloud/webdev/start_dev.py
```

(Originally written for the Windows dev box; falls back to `sys.executable`
on Linux.)

## EC2 deploy shape

Recommended production shape:

```text
Nginx :80
  /       -> /opt/zigbee-ble-orchestration-platform/cloud/webdev
  /api/*  -> http://127.0.0.1:8000
  /health -> http://127.0.0.1:8000
```

Minimal Nginx site:

```nginx
server {
    listen 80;
    server_name _;

    root /opt/zigbee-ble-orchestration-platform/cloud/webdev;
    index index.html;

    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /health {
        proxy_pass http://127.0.0.1:8000/health;
        proxy_set_header Host $host;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

No frontend build step is required.
