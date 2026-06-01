from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
EC2_COMPOSE = REPO_ROOT / "deploy" / "docker-compose.prod.yml"
SECURE_COMPOSE = REPO_ROOT / "deploy" / "docker-compose.prod-secure.yml"
PROD_MOSQUITTO_CONF = REPO_ROOT / "mqtt" / "config" / "mosquitto.prod.conf"
PROD_ACL_CONF = REPO_ROOT / "mqtt" / "config" / "acl.prod.conf"
DEPLOY_PS1 = REPO_ROOT / "deploy" / "deploy.ps1"
DEPLOY_SH = REPO_ROOT / "deploy" / "deploy.sh"


def test_secure_compose_uses_mqtt_tls_config_and_certs() -> None:
    compose = SECURE_COMPOSE.read_text(encoding="utf-8")

    assert "../mqtt/config/mosquitto.prod.conf:/mosquitto/config/mosquitto.conf:ro" in compose
    assert "../mqtt/config/acl.prod.conf:/mosquitto/config/acl.prod.conf:ro" in compose
    assert "${MQTT_CERT_DIR:-../mqtt/certs}:/mosquitto/certs:ro" in compose
    assert 'expose:\n      - "8883"' in compose
    assert '"1883"' not in compose


def test_ec2_compose_uses_mqtt_mtls_without_plaintext_ports() -> None:
    compose = EC2_COMPOSE.read_text(encoding="utf-8")

    assert "../mqtt/config/mosquitto.prod.conf:/mosquitto/config/mosquitto.conf:ro" in compose
    assert "../mqtt/config/acl.prod.conf:/mosquitto/config/acl.prod.conf:ro" in compose
    assert "${MQTT_CERT_DIR:-../mqtt/certs}:/mosquitto/certs:ro" in compose
    assert '"8883:8883"' in compose
    assert '"1883:1883"' not in compose
    assert '"9001:9001"' not in compose
    assert "mosquitto_sub -h localhost -p 8883 --cafile" in compose


def test_deploy_scripts_write_cloud_mqtt_mtls_environment() -> None:
    for script in (DEPLOY_PS1, DEPLOY_SH):
        text = script.read_text(encoding="utf-8")

        assert "setup-mqtt-mtls.sh" in text
        assert "SB_MQTT_PORT=8883" in text
        assert "SB_MQTT_TLS_ENABLED=true" in text
        assert "SB_MQTT_MTLS_ENABLED=true" in text
        assert "SB_MQTT_CA_CERT_PATH=/mosquitto/certs/ca.crt" in text
        assert "SB_MQTT_CLIENT_CERT_PATH=/mosquitto/certs/clients/cloud.crt" in text
        assert "SB_MQTT_CLIENT_KEY_PATH=/mosquitto/certs/clients/cloud.key" in text


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
