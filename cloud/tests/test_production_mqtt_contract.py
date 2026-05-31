from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SECURE_COMPOSE = REPO_ROOT / "deploy" / "docker-compose.prod-secure.yml"
PROD_MOSQUITTO_CONF = REPO_ROOT / "mqtt" / "config" / "mosquitto.prod.conf"
PROD_ACL_CONF = REPO_ROOT / "mqtt" / "config" / "acl.prod.conf"


def test_secure_compose_uses_mqtt_tls_config_and_certs() -> None:
    compose = SECURE_COMPOSE.read_text(encoding="utf-8")

    assert "../mqtt/config/mosquitto.prod.conf:/mosquitto/config/mosquitto.conf:ro" in compose
    assert "../mqtt/config/acl.prod.conf:/mosquitto/config/acl.prod.conf:ro" in compose
    assert "${MQTT_CERT_DIR:-../mqtt/certs}:/mosquitto/certs:ro" in compose
    assert 'expose:\n      - "8883"' in compose
    assert '"1883"' not in compose


def test_production_mosquitto_requires_mtls_on_8883() -> None:
    conf = PROD_MOSQUITTO_CONF.read_text(encoding="utf-8")

    assert "listener 8883 0.0.0.0" in conf
    assert "listener 1883" not in conf
    assert "listener 9001" not in conf
    assert "allow_anonymous false" in conf
    assert "password_file /mosquitto/passwords/passwd" in conf
    assert "acl_file /mosquitto/config/acl.prod.conf" in conf
    assert "cafile /mosquitto/certs/ca.crt" in conf
    assert "certfile /mosquitto/certs/server.crt" in conf
    assert "keyfile /mosquitto/certs/server.key" in conf
    assert "require_certificate true" in conf
    assert "use_identity_as_username false" in conf
    assert "BEGIN PRIVATE KEY" not in conf


def test_production_acl_scopes_cloud_gateway_and_monitor_users() -> None:
    acl = PROD_ACL_CONF.read_text(encoding="utf-8")

    assert "topic readwrite sb/v1/+/+/+/#" not in acl
    assert "user cloud" in acl
    assert "topic write sb/v1/+/+/+/commands/+/request" in acl
    assert "topic read sb/v1/+/+/+/commands/+/reply" in acl
    assert "user gateway" in acl
    assert "topic write sb/v1/+/+/+/devices/+/+/reported" in acl
    assert "topic read sb/v1/+/+/+/devices/+/+/desired" in acl
    assert "user monitor" in acl
    assert "topic read $SYS/#" in acl
    assert "BEGIN PRIVATE KEY" not in acl
