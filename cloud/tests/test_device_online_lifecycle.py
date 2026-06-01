"""Tests for device last_seen_at tracking and offline timeout policy."""
from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta

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


@pytest.mark.asyncio
async def test_device_out_exposes_last_seen_at(client, seed_light, db_session_factory):
    """`/api/devices/{id}` must expose `last_seen_at` so the UI can stop
    relying on the now-defunct `is_online=True` default."""
    from cloud.app.models import Device

    async with db_session_factory() as s:
        device = await s.get(Device, seed_light)
        device.last_seen_at = datetime(2026, 5, 21, 10, 0)
        await s.commit()

    headers = await _viewer_headers(client, db_session_factory)

    r = await client.get(f"/api/devices/{seed_light}", headers=headers)
    assert r.status_code == 200
    body = r.json()
    assert "last_seen_at" in body
    # Field is serialized with the same _fmt_ts helper as created_at/updated_at.
    assert body["last_seen_at"] is not None


@pytest.mark.asyncio
async def test_handle_reported_updates_last_seen_at(db_session_factory):
    """`_handle_reported` for an existing device must bump last_seen_at and
    set is_online=True so dashboard reflects current activity."""
    from cloud.app.models import Device, Home, Room
    from cloud.app.mqtt_client import MQTTService

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id="room-1", home_id="home-1", name="R"))
        s.add(
            Device(
                id="light-99",
                device_type="light",
                room_id="room-1",
                name="x",
                is_online=False,
                last_seen_at=None,
            )
        )
        await s.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    ts_ms = 1779000000000
    service._handle_reported(
        "sb/v1/hust/lab01/gw-ubuntu-01/devices/light/light-99/reported",
        {
            "schema": "sb.v1",
            "ts": ts_ms,
            "payload": {
                "device_id": "light-99",
                "device_type": "light",
                "state": {"power": "on", "level": 100, "reachable": True},
            },
        },
    )
    await tasks[0]

    async with db_session_factory() as s:
        device = await s.get(Device, "light-99")
        assert device.is_online is True
        assert device.last_seen_at is not None


@pytest.mark.asyncio
async def test_handle_event_updates_last_seen_at(db_session_factory):
    """Switch toggle events should also count as "device was alive just now"."""
    from cloud.app.models import Device, Home, Room
    from cloud.app.mqtt_client import MQTTService

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id="room-1", home_id="home-1", name="R"))
        s.add(
            Device(
                id="switch-99",
                device_type="switch",
                room_id="room-1",
                name="x",
                is_online=False,
                last_seen_at=None,
            )
        )
        await s.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    service._handle_event(
        "sb/v1/hust/lab01/gw-ubuntu-01/devices/switch/switch-99/event",
        {
            "schema": "sb.v1",
            "ts": 1779000000000,
            "payload": {
                "device_id": "switch-99",
                "device_type": "switch",
                "event": "toggle",
            },
        },
    )
    await tasks[0]

    async with db_session_factory() as s:
        device = await s.get(Device, "switch-99")
        assert device.is_online is True
        assert device.last_seen_at is not None


@pytest.mark.asyncio
async def test_handle_registry_updates_last_seen_at(db_session_factory):
    """Registry snapshots should also count as last_seen activity."""
    from cloud.app.models import Device
    from cloud.app.mqtt_client import MQTTService

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    service._handle_registry(
        "sb/v1/hust/lab01/gw-ubuntu-01/devices/motion/motion-99/registry",
        {
            "schema": "sb.v1",
            "ts": 1779000000000,
            "payload": {
                "device_id": "motion-99",
                "device_type": "motion",
                "eui64": "0000000000000099",
            },
        },
    )
    await tasks[0]

    async with db_session_factory() as s:
        device = await s.get(Device, "motion-99")
        assert device is not None
        assert device.is_online is True
        assert device.last_seen_at is not None


@pytest.mark.asyncio
async def test_mark_stale_devices_offline_marks_stale_rows(db_session_factory):
    """Reaper must mark `is_online=False` for devices whose last_seen_at
    is older than the configured threshold."""
    from cloud.app.device_lifecycle import mark_stale_devices_offline
    from cloud.app.models import Device, Home, Room

    now = datetime.now(UTC).replace(tzinfo=None)
    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id="room-1", home_id="home-1", name="R"))
        s.add_all(
            [
                Device(
                    id="recent",
                    device_type="light",
                    room_id="room-1",
                    name="r",
                    is_online=True,
                    last_seen_at=now - timedelta(seconds=10),
                ),
                Device(
                    id="stale",
                    device_type="light",
                    room_id="room-1",
                    name="s",
                    is_online=True,
                    last_seen_at=now - timedelta(seconds=600),
                ),
                Device(
                    id="never_seen",
                    device_type="probe",
                    room_id="room-1",
                    name="n",
                    is_online=True,
                    last_seen_at=None,
                ),
            ]
        )
        await s.commit()

    changed = await mark_stale_devices_offline(
        db_session_factory, threshold_seconds=300
    )
    assert changed == 2

    async with db_session_factory() as s:
        recent = await s.get(Device, "recent")
        stale = await s.get(Device, "stale")
        never = await s.get(Device, "never_seen")
        assert recent.is_online is True
        assert stale.is_online is False
        # Devices that have never reported are treated as offline so the
        # dashboard stops showing stale seed/probe entries as ONLINE.
        assert never.is_online is False
