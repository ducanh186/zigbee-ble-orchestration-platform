"""Security regression tests for API authentication."""
from __future__ import annotations

import pytest


@pytest.mark.asyncio
async def test_health_is_public(client):
    response = await client.get("/health")

    assert response.status_code == 200


@pytest.mark.asyncio
async def test_device_command_requires_bearer_token(
    client,
    fake_mqtt,
    seed_light,
):
    response = await client.post(
        f"/api/devices/{seed_light}/command",
        json={
            "op": "device.command",
            "target": {"endpoint": 1, "cluster_id": "0x0006", "command": "on"},
        },
    )

    assert response.status_code == 401
    assert fake_mqtt.published == []
