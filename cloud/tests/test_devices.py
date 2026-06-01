"""Tests for the devices router."""
from __future__ import annotations

from datetime import datetime

import pytest


@pytest.mark.asyncio
async def test_health(client):
    r = await client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_list_and_get_devices(client, seed_light):
    r = await client.get("/api/devices/")
    assert r.status_code == 200
    devices = r.json()
    assert any(d["id"] == seed_light for d in devices)

    r = await client.get(f"/api/devices/{seed_light}")
    assert r.status_code == 200
    assert r.json()["device_type"] == "light"


@pytest.mark.asyncio
async def test_get_device_state_404_when_no_state(client, seed_light):
    r = await client.get(f"/api/devices/{seed_light}/state")
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_get_device_state_returns_latest(
    client, seed_light, db_session_factory
):
    from cloud.app.models import DeviceState

    async with db_session_factory() as s:
        s.add(
            DeviceState(
                device_id=seed_light,
                state={"power": "off"},
                reported_at=datetime(2026, 4, 13, 7, 0),
            )
        )
        s.add(
            DeviceState(
                device_id=seed_light,
                state={"power": "on"},
                reported_at=datetime(2026, 4, 13, 7, 15),
            )
        )
        await s.commit()

    r = await client.get(f"/api/devices/{seed_light}/state")
    assert r.status_code == 200
    assert r.json()["state"]["power"] == "on"


@pytest.mark.asyncio
async def test_list_devices_filter_by_room(client, seed_light):
    r = await client.get("/api/devices/?room_id=room-1")
    assert r.status_code == 200
    assert [d["id"] for d in r.json()] == [seed_light]

    r = await client.get("/api/devices/?room_id=no-such-room")
    assert r.json() == []


@pytest.mark.asyncio
async def test_delete_device_cascades(client, seed_light, db_session_factory):
    from cloud.app.models import Command, DeviceState, Event

    async with db_session_factory() as s:
        s.add(
            DeviceState(
                device_id=seed_light,
                state={"power": "on"},
                reported_at=datetime(2026, 5, 19, 10, 0),
            )
        )
        s.add(
            Event(
                device_id=seed_light,
                event_type="device_registry",
                payload={"trigger": "attr_report"},
                occurred_at=datetime(2026, 5, 19, 10, 1),
            )
        )
        s.add(
            Command(
                id="cmd-1",
                device_id=seed_light,
                op="set",
                target={"power": "on"},
                status="executed",
            )
        )
        await s.commit()

    r = await client.delete(f"/api/devices/{seed_light}")
    assert r.status_code == 204

    r = await client.get(f"/api/devices/{seed_light}")
    assert r.status_code == 404

    from sqlalchemy import select
    async with db_session_factory() as s:
        states = (await s.execute(select(DeviceState).where(DeviceState.device_id == seed_light))).scalars().all()
        events = (await s.execute(select(Event).where(Event.device_id == seed_light))).scalars().all()
        commands = (await s.execute(select(Command).where(Command.device_id == seed_light))).scalars().all()
        assert states == []
        assert events == []
        assert commands == []


@pytest.mark.asyncio
async def test_delete_device_404_when_missing(client):
    r = await client.delete("/api/devices/nope")
    assert r.status_code == 404
