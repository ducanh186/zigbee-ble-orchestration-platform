"""
Tests for Pydantic contract models.
"""

import pytest

from gateway.src.models import IPCRecord, MQTTEnvelope, OTACampaignManifestPayload


def test_mqtt_envelope_requires_payload_namespace_fields():
    envelope = MQTTEnvelope(
        tenant_id="hust",
        site_id="lab01",
        gateway_id="gw-ubuntu-01",
        source="gateway",
        payload={"value": "online"},
    )

    assert envelope.model_dump(by_alias=True)["schema"] == "sb.v1"
    assert envelope.payload["value"] == "online"


def test_ipc_record_rejects_unknown_kind():
    with pytest.raises(ValueError):
        IPCRecord(kind="unknown", source="gateway", payload={})


def test_ota_manifest_validates_sha256():
    with pytest.raises(ValueError):
        OTACampaignManifestPayload.model_validate(
            {
                "campaign_id": "camp-01",
                "target": {"device_type": "light"},
                "artifact": {
                    "url": "file:///tmp/test.ota",
                    "sha256": "bad",
                    "size_bytes": 10,
                },
            }
        )
