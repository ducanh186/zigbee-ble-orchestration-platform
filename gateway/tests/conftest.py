"""
Shared fixtures and test doubles for gateway bridge tests.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

import pytest

from gateway.src.bridge import GatewayBridge
from gateway.src.config import BridgeSettings
from gateway.src.models import MQTTEnvelope


class FakeMQTTPublisher:
    """Capture MQTT publishes for assertions."""

    def __init__(self):
        self.published: list[dict[str, object]] = []

    def publish(self, topic: str, payload: str, qos: int = 0, retain: bool = False):
        self.published.append(
            {
                "topic": topic,
                "payload": payload,
                "qos": qos,
                "retain": retain,
            }
        )


class FakeIPCServer:
    """Capture IPC sends without opening a real Unix socket."""

    def __init__(self):
        self.sent_records = []
        self.is_connected = True

    def send(self, record):
        if not self.is_connected:
            return False
        self.sent_records.append(record)
        return True


@pytest.fixture()
def settings(tmp_path: Path) -> BridgeSettings:
    return BridgeSettings(
        sb_tenant_id="hust",
        sb_site_id="lab01",
        sb_gateway_id="gw-ubuntu-01",
        sb_mqtt_host="localhost",
        sb_mqtt_port=1883,
        sb_ipc_socket_path=str(tmp_path / "bridge.sock"),
        sb_ota_dir=str(tmp_path / "ota-files"),
        sb_command_timeout_ms=100,
        sb_log_level="INFO",
    )


@pytest.fixture()
def fake_mqtt() -> FakeMQTTPublisher:
    return FakeMQTTPublisher()


@pytest.fixture()
def fake_ipc() -> FakeIPCServer:
    return FakeIPCServer()


@pytest.fixture()
def bridge(settings: BridgeSettings, fake_mqtt: FakeMQTTPublisher, fake_ipc: FakeIPCServer) -> GatewayBridge:
    runtime = GatewayBridge(settings, fake_mqtt, fake_ipc)
    runtime.start()
    yield runtime
    runtime.stop()


def make_envelope_json(
    settings: BridgeSettings,
    payload: dict,
    *,
    source: str = "gateway",
    correlation_id: str | None = None,
    trace_id: str | None = None,
) -> str:
    """Build a valid MQTT envelope for test inputs."""

    return MQTTEnvelope(
        tenant_id=settings.tenant_id,
        site_id=settings.site_id,
        gateway_id=settings.gateway_id,
        source=source,
        correlation_id=correlation_id,
        trace_id=trace_id,
        payload=payload,
    ).model_dump_json(exclude_none=True, by_alias=True)


@pytest.fixture()
def staged_artifact_payload(tmp_path: Path) -> dict:
    artifact = tmp_path / "sample.ota"
    artifact_bytes = b"sample ota payload"
    artifact.write_bytes(artifact_bytes)
    return {
        "url": artifact.as_uri(),
        "sha256": hashlib.sha256(artifact_bytes).hexdigest(),
        "size_bytes": len(artifact_bytes),
        "file_version": 3,
        "stack_version": "zigbee-8.x",
    }
