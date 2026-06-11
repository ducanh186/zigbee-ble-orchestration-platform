from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
EC2_COMPOSE = REPO_ROOT / "deploy" / "docker-compose.prod.yml"
SECURE_COMPOSE = REPO_ROOT / "deploy" / "docker-compose.prod-secure.yml"
PROD_MOSQUITTO_CONF = REPO_ROOT / "mqtt" / "config" / "mosquitto.prod.conf"
EXAMPLE_INVENTORY = REPO_ROOT / "deploy" / "mqtt-gateways.example.csv"
IDENTITY_TOOL = REPO_ROOT / "deploy" / "mqtt_identity.py"
GATEWAY_HANDOFF = (
    REPO_ROOT
    / "docs"
    / "handoffs"
    / "MQTT_GATEWAY_CERT_IDENTITY_HANDOFF.md"
)
DEPLOY_PS1 = REPO_ROOT / "deploy" / "deploy.ps1"
DEPLOY_SH = REPO_ROOT / "deploy" / "deploy.sh"


def test_secure_compose_uses_mqtt_tls_config_and_certs() -> None:
    compose = SECURE_COMPOSE.read_text(encoding="utf-8")

    assert "../mqtt/config/mosquitto.prod.conf:/mosquitto/config/mosquitto.conf:ro" in compose
    assert "./mosquitto/generated/acl.prod.conf:/mosquitto/config/acl.prod.conf:ro" in compose
    assert "/ca/ca.key:" not in compose
    assert "./mosquitto/pki/ca/ca.crt:/mosquitto/certs/ca.crt:ro" in compose
    assert "./mosquitto/pki/server/server.crt:/mosquitto/certs/server.crt:ro" in compose
    assert "./mosquitto/pki/server/server.key:/mosquitto/certs/server.key:ro" in compose
    assert 'expose:\n      - "8883"' in compose
    assert '"1883"' not in compose
    assert "mosquitto/passwords" not in compose


def test_ec2_compose_uses_mqtt_mtls_without_plaintext_ports() -> None:
    compose = EC2_COMPOSE.read_text(encoding="utf-8")

    assert "../mqtt/config/mosquitto.prod.conf:/mosquitto/config/mosquitto.conf:ro" in compose
    assert "./mosquitto/generated/acl.prod.conf:/mosquitto/config/acl.prod.conf:ro" in compose
    assert "/ca/ca.key:" not in compose
    assert "./mosquitto/pki/clients/cloud-control.crt:/mosquitto/certs/clients/cloud-control.crt:ro" in compose
    assert "./mosquitto/pki/clients/cloud-control.key:/mosquitto/certs/clients/cloud-control.key:ro" in compose
    assert '"8883:8883"' in compose
    assert '"1883:1883"' not in compose
    assert '"9001:9001"' not in compose
    assert "mosquitto_sub -h localhost -p 8883 --cafile" in compose
    assert " -u " not in compose
    assert " -P " not in compose
    assert "mosquitto/passwords" not in compose


def test_deploy_scripts_write_cloud_mqtt_mtls_environment() -> None:
    for script in (DEPLOY_PS1, DEPLOY_SH):
        text = script.read_text(encoding="utf-8")

        assert "setup-mqtt-mtls.sh" in text
        assert "SB_MQTT_PORT=8883" in text
        assert "SB_MQTT_CERT_IDENTITY_ENABLED=true" in text
        assert "SB_MQTT_TLS_ENABLED=true" in text
        assert "SB_MQTT_MTLS_ENABLED=true" in text
        assert "SB_MQTT_CA_CERT_PATH=/mosquitto/certs/ca.crt" in text
        assert "SB_MQTT_CLIENT_CERT_PATH=/mosquitto/certs/clients/cloud-control.crt" in text
        assert "SB_MQTT_CLIENT_KEY_PATH=/mosquitto/certs/clients/cloud-control.key" in text
        assert "mosquitto_passwd" not in text
        assert "MQTT_GATEWAY_PASS" not in text
        assert "MQTT_CLOUD_PASS" not in text
        assert "SB_MQTT_USERNAME=" not in text
        assert "SB_MQTT_PASSWORD=" not in text


def test_production_mosquitto_requires_mtls_on_8883() -> None:
    conf = PROD_MOSQUITTO_CONF.read_text(encoding="utf-8")

    assert "listener 8883 0.0.0.0" in conf
    assert "listener 1883" not in conf
    assert "listener 9001" not in conf
    assert "allow_anonymous false" in conf
    assert "password_file" not in conf
    assert "acl_file /mosquitto/config/acl.prod.conf" in conf
    assert "cafile /mosquitto/certs/ca.crt" in conf
    assert "certfile /mosquitto/certs/server.crt" in conf
    assert "keyfile /mosquitto/certs/server.key" in conf
    assert "require_certificate true" in conf
    assert "use_identity_as_username true" in conf
    assert "BEGIN PRIVATE KEY" not in conf


def test_repository_contains_inventory_template_and_generator() -> None:
    assert EXAMPLE_INVENTORY.read_text(encoding="utf-8").splitlines()[0] == (
        "principal_id,tenant_id,site_id,gateway_id,csr_file"
    )
    assert IDENTITY_TOOL.is_file()


def test_gateway_certificate_identity_handoff_is_complete() -> None:
    handoff = GATEWAY_HANDOFF.read_text(encoding="utf-8")

    for requirement in (
        "SB_MQTT_CERT_IDENTITY_ENABLED=true",
        "SB_MQTT_PRINCIPAL_ID",
        "SB_MQTT_USERNAME",
        "SB_MQTT_PASSWORD",
        "z3gw-host",
        "principal_id",
        "tenant/site/gateway",
        "Readiness Checklist",
        "Smoke Tests",
        "Coordinated Cutover",
        "Rollback",
    ):
        assert requirement in handoff
