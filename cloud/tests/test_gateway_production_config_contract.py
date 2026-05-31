from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
APP_MQTT = REPO_ROOT / "gateway" / "Z3GatewayHost" / "app" / "app_mqtt.c"
BRIDGE_TEMPLATE = REPO_ROOT / "mqtt" / "config" / "bridge.conf"
BRIDGE_CONF_D = REPO_ROOT / "mqtt" / "config" / "conf.d" / "bridge.conf"


def test_gateway_source_has_no_demo_mqtt_endpoint_or_password_fallbacks() -> None:
    source = APP_MQTT.read_text(encoding="utf-8")

    assert "98.83.4.87" not in source
    assert "52.199.233.62" not in source
    assert "gateway123" not in source
    assert 'MQTT_HOST_DEFAULT     "localhost"' in source
    assert 'MQTT_PASSWORD_DEFAULT ""' in source


def test_gateway_production_mode_requires_mqtt_and_tls_environment() -> None:
    source = APP_MQTT.read_text(encoding="utf-8")

    assert 'getenv("SB_ENV")' in source
    assert 'getenv("SB_PRODUCTION")' in source
    assert 'requireEnv("SB_MQTT_HOST"' in source
    assert 'requireEnv("SB_MQTT_PORT"' in source
    assert 'requireEnv("SB_MQTT_USERNAME"' in source
    assert 'requireEnv("SB_MQTT_PASSWORD"' in source
    assert 'requireEnv("SB_MQTT_CA_CERT_PATH"' in source
    assert 'requireEnv("SB_MQTT_CLIENT_CERT_PATH"' in source
    assert 'requireEnv("SB_MQTT_CLIENT_KEY_PATH"' in source
    assert "mosquitto_tls_set" in source


def test_gateway_topic_identity_is_runtime_configurable() -> None:
    source = APP_MQTT.read_text(encoding="utf-8")

    assert 'getenv("SB_TENANT_ID")' in source
    assert 'getenv("SB_SITE_ID")' in source
    assert 'getenv("SB_GATEWAY_ID")' in source
    assert "MQTT_PREFIX  \"sb/v1/\" MQTT_TENANT" not in source
    assert "snprintf(sMqttPrefix" in source


def test_bridge_config_templates_use_placeholders_not_real_endpoints() -> None:
    bridge = BRIDGE_TEMPLATE.read_text(encoding="utf-8")
    conf_d = BRIDGE_CONF_D.read_text(encoding="utf-8")
    combined = bridge + "\n" + conf_d

    assert "98.83.4.87" not in combined
    assert "52.199.233.62" not in combined
    assert "bridge123" not in combined
    assert "<REMOTE_MQTT_HOST>" in combined
    assert "<REMOTE_BRIDGE_PASSWORD>" in combined
