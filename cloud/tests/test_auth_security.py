"""Security regression tests for API authentication."""
from __future__ import annotations

import pytest


@pytest.mark.asyncio
async def test_health_is_public(unauthenticated_client):
    response = await unauthenticated_client.get("/health")

    assert response.status_code == 200


@pytest.mark.asyncio
async def test_device_command_requires_bearer_token(
    unauthenticated_client,
    fake_mqtt,
    seed_light,
):
    response = await unauthenticated_client.post(
        f"/api/devices/{seed_light}/command",
        json={
            "op": "device.command",
            "target": {"endpoint": 1, "cluster_id": "0x0006", "command": "on"},
        },
    )

    assert response.status_code == 401
    assert fake_mqtt.published == []
