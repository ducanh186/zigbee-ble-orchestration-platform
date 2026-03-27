"""
Bridge integration tests for MQTT, IPC, and OTA staging behavior.
"""

from pathlib import Path

from gateway.src.models import IPCRecord

from .conftest import make_envelope_json


def test_bridge_routes_registry_health_log_and_desired(bridge, fake_mqtt, fake_ipc, settings):
    bridge.handle_ipc_record(
        IPCRecord(
            kind="registry",
            source="adapter",
            device_id="light-01",
            payload={"device_id": "light-01", "device_type": "light"},
        )
    )
    bridge.handle_ipc_record(
        IPCRecord(
            kind="gateway_health",
            source="gateway",
            payload={"status": "degraded"},
        )
    )
    bridge.handle_ipc_record(
        IPCRecord(
            kind="gateway_log",
            source="gateway",
            payload={"event": "boot", "message": "ok"},
        )
    )

    assert fake_mqtt.published[0]["topic"] == "sb/v1/hust/lab01/gw-ubuntu-01/devices/light-01/registry"
    assert fake_mqtt.published[0]["retain"] is True
    assert fake_mqtt.published[1]["topic"] == "sb/v1/hust/lab01/gw-ubuntu-01/gateway/health"
    assert fake_mqtt.published[1]["retain"] is True
    assert fake_mqtt.published[2]["topic"] == "sb/v1/hust/lab01/gw-ubuntu-01/gateway/log"
    assert fake_mqtt.published[2]["retain"] is False

    desired_json = make_envelope_json(
        settings,
        {"device_id": "light-01", "desired": {"power": "off"}},
        source="cloud",
    )
    bridge.handle_mqtt_message(
        "sb/v1/hust/lab01/gw-ubuntu-01/devices/light-01/desired",
        desired_json,
    )

    assert fake_ipc.sent_records[-1].kind == "desired"
    assert fake_ipc.sent_records[-1].device_id == "light-01"


def test_bridge_command_lifecycle_and_terminal_reply(bridge, fake_mqtt, fake_ipc, settings):
    request_json = make_envelope_json(
        settings,
        {
            "device_id": "light-01",
            "op": "device.command",
            "target": {"cluster_id": "0x0006", "command": "off"},
            "timeout_ms": 500,
        },
        source="mobile",
        correlation_id="cmd-01",
    )
    bridge.handle_mqtt_message(
        "sb/v1/hust/lab01/gw-ubuntu-01/commands/cmd-01/request",
        request_json,
    )

    lifecycle_topics = [entry["topic"] for entry in fake_mqtt.published]
    assert lifecycle_topics[:3] == [
        "sb/v1/hust/lab01/gw-ubuntu-01/commands/cmd-01/reply",
        "sb/v1/hust/lab01/gw-ubuntu-01/commands/cmd-01/reply",
        "sb/v1/hust/lab01/gw-ubuntu-01/commands/cmd-01/reply",
    ]
    assert fake_ipc.sent_records[-1].kind == "command_request"

    bridge.handle_ipc_record(
        IPCRecord(
            kind="command_reply",
            source="adapter",
            command_id="cmd-01",
            correlation_id="cmd-01",
            device_id="light-01",
            status="executed",
            payload={"device_id": "light-01", "status": "executed"},
        )
    )

    assert fake_mqtt.published[-1]["topic"] == "sb/v1/hust/lab01/gw-ubuntu-01/commands/cmd-01/reply"


def test_bridge_stages_ota_artifact_and_emits_progress(bridge, fake_mqtt, fake_ipc, settings, staged_artifact_payload):
    manifest_json = make_envelope_json(
        settings,
        {
            "campaign_id": "camp-01",
            "target": {"device_type": "light", "image_type": "0x0001"},
            "artifact": staged_artifact_payload,
        },
        source="cloud",
    )
    bridge.handle_mqtt_message(
        "sb/v1/hust/lab01/gw-ubuntu-01/ota/campaigns/camp-01/manifest",
        manifest_json,
    )
    assert fake_ipc.sent_records[-1].kind == "ota_manifest"

    desired_json = make_envelope_json(
        settings,
        {"campaign_id": "camp-01", "action": "stage_and_offer"},
        source="cloud",
    )
    bridge.handle_mqtt_message(
        "sb/v1/hust/lab01/gw-ubuntu-01/ota/devices/light-01/desired",
        desired_json,
    )

    progress_topics = [entry["topic"] for entry in fake_mqtt.published if str(entry["topic"]).endswith("/progress")]
    assert progress_topics == [
        "sb/v1/hust/lab01/gw-ubuntu-01/ota/devices/light-01/progress",
        "sb/v1/hust/lab01/gw-ubuntu-01/ota/devices/light-01/progress",
    ]
    assert fake_ipc.sent_records[-1].kind == "ota_desired"

    artifact_path = Path(fake_ipc.sent_records[-1].payload["local_artifact_path"])
    assert artifact_path.exists()
