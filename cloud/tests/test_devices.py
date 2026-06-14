"""Tests for the devices router."""
from __future__ import annotations

from datetime import datetime

import pytest

from cloud.tests.auth_helpers import create_auth_user, login_headers


async def _viewer_headers(client, db_session_factory) -> dict[str, str]:
    await create_auth_user(
        db_session_factory,
        user_id="viewer-1",
        username="viewer",
        role="viewer",
        password="viewer-pass",
        home_id="home-1",
    )
    return await login_headers(client, "viewer", "viewer-pass")


async def _admin_headers(client, db_session_factory) -> dict[str, str]:
    await create_auth_user(
        db_session_factory,
        user_id="admin-1",
        username="admin",
        role="admin",
        password="admin-pass",
        home_id=None,
    )
    return await login_headers(client, "admin", "admin-pass")


@pytest.mark.asyncio
async def test_health(client):
    r = await client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_list_and_get_devices(client, seed_light, db_session_factory):
    headers = await _viewer_headers(client, db_session_factory)

    r = await client.get("/api/devices/", headers=headers)
    assert r.status_code == 200
    devices = r.json()
    assert any(d["id"] == seed_light for d in devices)

    r = await client.get(f"/api/devices/{seed_light}", headers=headers)
    assert r.status_code == 200
    assert r.json()["device_type"] == "light"


@pytest.mark.asyncio
async def test_get_device_state_404_when_no_state(
    client, seed_light, db_session_factory
):
    headers = await _viewer_headers(client, db_session_factory)

    r = await client.get(f"/api/devices/{seed_light}/state", headers=headers)
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

    headers = await _viewer_headers(client, db_session_factory)

    r = await client.get(f"/api/devices/{seed_light}/state", headers=headers)
    assert r.status_code == 200
    assert r.json()["state"]["power"] == "on"


@pytest.mark.asyncio
async def test_list_devices_filter_by_room(client, seed_light, db_session_factory):
    headers = await _viewer_headers(client, db_session_factory)

    r = await client.get("/api/devices/?room_id=room-1", headers=headers)
    assert r.status_code == 200
    assert [d["id"] for d in r.json()] == [seed_light]

    r = await client.get("/api/devices/?room_id=no-such-room", headers=headers)
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

    headers = await _admin_headers(client, db_session_factory)

    r = await client.delete(f"/api/devices/{seed_light}", headers=headers)
    assert r.status_code == 204

    r = await client.get(f"/api/devices/{seed_light}", headers=headers)
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
async def test_delete_device_404_when_missing(client, db_session_factory):
    headers = await _admin_headers(client, db_session_factory)

    r = await client.delete("/api/devices/nope", headers=headers)
    assert r.status_code == 404


async def _parent_headers(client, db_session_factory) -> dict[str, str]:
    await create_auth_user(
        db_session_factory,
        user_id="parent-1",
        username="parent",
        role="parent",
        password="parent-pass",
        home_id="home-1",
    )
    return await login_headers(client, "parent", "parent-pass")


@pytest.mark.asyncio
async def test_update_device_name_only_keeps_room(
    client, seed_light, db_session_factory
):
    headers = await _parent_headers(client, db_session_factory)

    r = await client.patch(
        f"/api/devices/{seed_light}",
        headers=headers,
        json={"name": "Renamed Light"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["name"] == "Renamed Light"
    # room is untouched when room_id is omitted
    assert body["room_id"] == "room-1"


@pytest.mark.asyncio
async def test_update_device_moves_to_room_in_home(
    client, seed_light, db_session_factory
):
    from cloud.app.models import Room

    async with db_session_factory() as s:
        s.add(Room(id="room-2", home_id="home-1", name="Bedroom"))
        await s.commit()

    headers = await _parent_headers(client, db_session_factory)

    r = await client.patch(
        f"/api/devices/{seed_light}",
        headers=headers,
        json={"name": "Main Light", "room_id": "room-2"},
    )
    assert r.status_code == 200
    assert r.json()["room_id"] == "room-2"


@pytest.mark.asyncio
async def test_update_device_room_only_without_name(
    client, seed_light, db_session_factory
):
    """A room move must not require re-sending the device name (name optional)."""
    from cloud.app.models import Room

    async with db_session_factory() as s:
        s.add(Room(id="room-2", home_id="home-1", name="Bedroom"))
        await s.commit()

    headers = await _parent_headers(client, db_session_factory)

    r = await client.patch(
        f"/api/devices/{seed_light}",
        headers=headers,
        json={"room_id": "room-2"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["room_id"] == "room-2"
    # name is untouched when omitted
    assert body["name"] == "Main Light"


@pytest.mark.asyncio
async def test_update_device_empty_body_rejected(
    client, seed_light, db_session_factory
):
    """Neither name nor room_id provided is a 422 (nothing to update)."""
    headers = await _parent_headers(client, db_session_factory)

    r = await client.patch(
        f"/api/devices/{seed_light}",
        headers=headers,
        json={},
    )
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_update_device_room_outside_home_forbidden(
    client, seed_light, db_session_factory
):
    from cloud.app.models import Home, Room

    async with db_session_factory() as s:
        s.add(Home(id="home-2", name="Other Home"))
        s.add(Room(id="room-other", home_id="home-2", name="Garage"))
        await s.commit()

    headers = await _parent_headers(client, db_session_factory)

    r = await client.patch(
        f"/api/devices/{seed_light}",
        headers=headers,
        json={"name": "Main Light", "room_id": "room-other"},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_update_device_room_missing_404(
    client, seed_light, db_session_factory
):
    headers = await _parent_headers(client, db_session_factory)

    r = await client.patch(
        f"/api/devices/{seed_light}",
        headers=headers,
        json={"name": "Main Light", "room_id": "ghost-room"},
    )
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_update_device_requires_parent_or_admin(
    client, seed_light, db_session_factory
):
    headers = await _viewer_headers(client, db_session_factory)

    r = await client.patch(
        f"/api/devices/{seed_light}",
        headers=headers,
        json={"name": "Nope"},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_patch_room_publishes_set_room_command(
    client, seed_light, db_session_factory, fake_mqtt
):
    """Moving a device to a room should publish device.set_room via MQTT."""
    from cloud.app.models import Room

    async with db_session_factory() as s:
        s.add(Room(id="room-2", home_id="home-1", name="Bedroom"))
        await s.commit()

    headers = await _parent_headers(client, db_session_factory)

    r = await client.patch(
        f"/api/devices/{seed_light}",
        headers=headers,
        json={"name": "Main Light", "room_id": "room-2"},
    )
    assert r.status_code == 200
    assert r.json()["room_id"] == "room-2"

    set_room_entries = [
        e for e in fake_mqtt.published if e["op"] == "device.set_room"
    ]
    assert len(set_room_entries) == 1
    entry = set_room_entries[0]
    assert entry["device_id"] == seed_light
    assert entry["target"] == {"room_id": "room-2"}


@pytest.mark.asyncio
async def test_patch_name_only_does_not_publish_set_room(
    client, seed_light, db_session_factory, fake_mqtt
):
    """Renaming a device (no room_id change) must NOT publish device.set_room."""
    headers = await _parent_headers(client, db_session_factory)

    r = await client.patch(
        f"/api/devices/{seed_light}",
        headers=headers,
        json={"name": "Renamed Light"},
    )
    assert r.status_code == 200
    assert r.json()["room_id"] == "room-1"

    set_room_entries = [
        e for e in fake_mqtt.published if e["op"] == "device.set_room"
    ]
    assert set_room_entries == []


@pytest.mark.asyncio
async def test_device_out_includes_sensor_kind(client, db_session_factory):
    from cloud.app.models import Device, Home, Room

    async with db_session_factory() as s:
        s.add(Home(id="home-sk", name="Sensor Home"))
        s.add(Room(id="room-sk", home_id="home-sk", name="Hall"))
        s.add(
            Device(
                id="env-sensor-01",
                device_type="sensor",
                sensor_kind=2,
                room_id="room-sk",
                name="DHT11",
                is_online=True,
            )
        )
        await s.commit()

    await create_auth_user(
        db_session_factory,
        user_id="viewer-sk",
        username="viewer-sk",
        role="viewer",
        password="pass-sk",
        home_id="home-sk",
    )
    headers = await login_headers(client, "viewer-sk", "pass-sk")

    r = await client.get("/api/devices/env-sensor-01", headers=headers)
    assert r.status_code == 200
    body = r.json()
    assert body["sensor_kind"] == 2
    assert body["device_type"] == "sensor"
