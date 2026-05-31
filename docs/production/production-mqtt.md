# Production MQTT TLS and ACL Evidence

Scope: SCRUM-95, Phase 3 MQTT TLS/mTLS and broker ACL hardening.

## Status

Production MQTT config is locally verified by static contract tests and Docker Compose config parsing. Live broker handshake tests are not run in this local environment because production certificates, passwords, and EC2 security-group state are operator-controlled.

## Production Broker Contract

| Item | Production value | Evidence |
|---|---|---|
| Listener | `8883` only in secure production compose and production Mosquitto config. | `mqtt/config/mosquitto.prod.conf`, `deploy/docker-compose.prod-secure.yml` |
| Plain MQTT | No production `listener 1883`; no public `1883:1883` mapping. | `cloud/tests/test_production_mqtt_contract.py` |
| WebSocket MQTT | No production `listener 9001`. | `cloud/tests/test_production_mqtt_contract.py` |
| TLS | `cafile`, `certfile`, and `keyfile` are required. | `mqtt/config/mosquitto.prod.conf` |
| mTLS | `require_certificate true`. | `mqtt/config/mosquitto.prod.conf` |
| Anonymous access | `allow_anonymous false`. | `mqtt/config/mosquitto.prod.conf` |
| Password auth | `password_file /mosquitto/passwords/passwd`. | `mqtt/config/mosquitto.prod.conf` |
| ACL | `acl_file /mosquitto/config/acl.prod.conf`. | `mqtt/config/acl.prod.conf` |

## ACL Contract

| User | Permission intent |
|---|---|
| `cloud` | Reads gateway/device uplink state and command replies; writes desired state, commands, OTA desired, group/scene/automation desired topics. |
| `gateway` | Writes gateway/device uplink state and command replies; reads desired state, commands, OTA desired, group/scene/automation desired topics. |
| `monitor` | Reads `$SYS/#` and a narrow operational status subset. |

The production ACL intentionally avoids broad `topic readwrite sb/v1/+/+/+/#` grants.

## Certificate Layout

Expected mounted production certificate directory:

```text
mqtt/certs/
  ca.crt
  server.crt
  server.key
  clients/
    cloud.crt
    cloud.key
    gateway.crt
    gateway.key
    monitor.crt
    monitor.key
```

Repository rule: only `mqtt/certs/.gitignore` is committed. Real certificates and private keys must be provisioned outside git.

## Negative Test Procedure

Run these only against an operator-approved production-like broker with test credentials and certificates:

```text
mosquitto_sub -h <BROKER_HOST> -p 8883 -t '$SYS/broker/uptime' -C 1 -W 3
Expected: fail because no CA/client certificate is provided.
```

```text
mosquitto_pub -h <BROKER_HOST> -p 8883 --cafile ca.crt --cert monitor.crt --key monitor.key -u monitor -P <MONITOR_PASSWORD> -t 'sb/v1/hust/lab01/gw-ubuntu-01/commands/test/request' -m '{}'
Expected: fail because `monitor` has no command write ACL.
```

```text
mosquitto_sub -h <BROKER_HOST> -p 8883 --cafile ca.crt --cert wrong-client.crt --key wrong-client.key -u gateway -P <GATEWAY_PASSWORD> -t 'sb/v1/hust/lab01/gw-ubuntu-01/commands/+/request' -C 1 -W 3
Expected: fail when the certificate is not signed by the trusted production CA or is not accepted by operator policy.
```

## Verification

RED evidence before implementation:

```text
python -m pytest cloud/tests/test_production_mqtt_contract.py -q
3 failed
```

GREEN evidence after implementation:

```text
python -m pytest cloud/tests/test_production_mqtt_contract.py -q
3 passed in 0.06s
```

Compose validation:

```text
docker compose --env-file .env.prod -f docker-compose.prod-secure.yml config
PASS
```
