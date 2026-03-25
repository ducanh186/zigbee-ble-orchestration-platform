# MQTT Broker

This folder contains the local Mosquitto setup for the `sb/v1` namespace used by the gateway bridge.

## Files kept in scope

- `config/mosquitto.conf`
- `config/acl.conf`
- `docker/docker-compose.yml`

## Topic namespace

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/...
```

## Local start

```bash
cd mqtt/docker
docker compose up -d
```

The compose setup expects:

- `mqtt/passwords/passwd`
- `mqtt/data/`

## Principals

- `gateway`: read/write access to the gateway namespace
- `client`: read state/health/log/replies/progress, write desired/request/manifest
- `monitor`: read-only access

## Ports

- `1883`: MQTT
- `9001`: MQTT over WebSocket
