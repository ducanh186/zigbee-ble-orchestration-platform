# Cloud Ops Console

Static web UI for checking cloud events, device state, gateway commissioning,
and command status during development.

## Local dev

One-command startup:

```powershell
cd F:\zigbee-ble-orchestration-platform
.\.venv\Scripts\python.exe .\cloud\webdev\start_dev.py
```

Open:

```text
http://localhost:5173
```

Press `Ctrl+C` in that terminal to stop both the Cloud API and Web UI.

### Manual startup

The local dev backend can run without Postgres by using the repo-root `.env`
file:

```powershell
cd F:\zigbee-ble-orchestration-platform
@"
SB_DATABASE_URL=sqlite+aiosqlite:///./cloud/dev.db
SB_MQTT_HOST=localhost
SB_MQTT_PORT=1883
SB_MQTT_USERNAME=client
SB_MQTT_PASSWORD=client
SB_TENANT_ID=hust
SB_SITE_ID=lab01
SB_GATEWAY_ID=gw-ubuntu-01
SB_API_HOST=127.0.0.1
SB_API_PORT=8000
"@ | Set-Content .env
```

Seed the dev database:

```powershell
cd F:\zigbee-ble-orchestration-platform
.\.venv\Scripts\python.exe -m cloud.app.seed
```

Run the cloud backend:

```powershell
cd F:\zigbee-ble-orchestration-platform
.\.venv\Scripts\python.exe -m uvicorn cloud.app.main:app --host 127.0.0.1 --port 8000
```

Run the UI dev server:

```powershell
cd F:\zigbee-ble-orchestration-platform\cloud\webdev
python .\dev_server.py
```

Open:

```text
http://localhost:5173
```

The dev server proxies `/api/*` and `/health` to `http://127.0.0.1:8000`.
Override the backend target when needed:

```powershell
$env:API_TARGET="http://<ec2-public-ip>:8000"; python .\dev_server.py
```

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
