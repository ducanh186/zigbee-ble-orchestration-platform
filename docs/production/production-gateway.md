# Production Gateway Config Evidence

Scope: SCRUM-96, Phase 4 gateway config hardening and secret fallback removal.

## Status

Gateway production config is locally verified by static contract tests. Live startup on physical gateway hardware is not run in this environment.

Implementation requirements for the Gateway owner are tracked in
`docs/production/gateway-localzigbee-security-requirements.md`. That document
is the checklist for live Gateway evidence and must be satisfied before stable
production readiness is claimed.

## Production Mode

The gateway MQTT module treats either of these as production mode:

```text
SB_ENV=production
SB_PRODUCTION=1
```

In production mode, startup validation fails fast if any required value is missing:

```text
SB_MQTT_HOST
SB_MQTT_PORT
SB_MQTT_USERNAME
SB_MQTT_PASSWORD
SB_TENANT_ID
SB_SITE_ID
SB_GATEWAY_ID
SB_MQTT_CA_CERT_PATH
SB_MQTT_CLIENT_CERT_PATH
SB_MQTT_CLIENT_KEY_PATH
```

## Gateway MQTT Contract

| Item | Production behavior | Evidence |
|---|---|---|
| Broker host | Must come from `SB_MQTT_HOST`; no public IP fallback in source. | `gateway/Z3GatewayHost/app/app_mqtt.c` |
| Broker port | Must come from `SB_MQTT_PORT`; production target is `8883`. | `gateway/Z3GatewayHost/app/app_mqtt.c` |
| Username/password | Must come from environment in production. | `gateway/Z3GatewayHost/app/app_mqtt.c` |
| TLS/mTLS | `mosquitto_tls_set` uses CA, client cert, and client key paths from env. | `gateway/Z3GatewayHost/app/app_mqtt.c` |
| Tenant/site/gateway id | Runtime configurable via env. | `gateway/Z3GatewayHost/app/app_mqtt.c` |
| Bridge config | Templates use placeholders only. | `mqtt/config/bridge.conf`, `mqtt/config/conf.d/bridge.conf` |

## Development Mode

Development mode keeps local defaults so local work remains possible:

```text
SB_MQTT_HOST=localhost
SB_MQTT_PORT=1883
SB_MQTT_USERNAME=gateway
SB_MQTT_PASSWORD=
SB_TENANT_ID=hust
SB_SITE_ID=lab01
SB_GATEWAY_ID=gw-ubuntu-01
```

If the local broker requires a password, set `SB_MQTT_PASSWORD` explicitly.

## Verification

RED evidence before implementation:

```text
python -m pytest cloud/tests/test_gateway_production_config_contract.py -q
4 failed
```

GREEN evidence after implementation:

```text
python -m pytest cloud/tests/test_gateway_production_config_contract.py -q
4 passed in 0.11s
```

Full cloud test suite:

```text
python -m pytest cloud/tests -q
146 passed, 21 skipped
```
