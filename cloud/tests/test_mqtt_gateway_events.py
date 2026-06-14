import asyncio
import sys
import types
import unittest

from cloud.app.mqtt_client import MQTTService


class _FakeSession:
    def __init__(self):
        self.added = []
        self.committed = False

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, traceback):
        return False

    def add(self, entity):
        self.added.append(entity)

    async def commit(self):
        self.committed = True


class GatewayEventPersistenceTest(unittest.TestCase):
    def test_gateway_online_message_is_saved_as_event_log(self):
        service = MQTTService()
        session = _FakeSession()
        service.set_db_session_factory(lambda: session)
        service._run_async = lambda coro_func: asyncio.run(coro_func())
        fake_models = types.ModuleType("cloud.app.models")
        fake_models.Event = _FakeEvent
        previous_models = sys.modules.get("cloud.app.models")
        sys.modules["cloud.app.models"] = fake_models

        try:
            service._handle_gateway_online(
                {
                    "ts": "2026-05-07T10:12:00+00:00",
                    "gateway_id": "gw-ubuntu-01",
                    "source": "gateway",
                    "payload": {"value": "online"},
                }
            )
        finally:
            if previous_models is None:
                del sys.modules["cloud.app.models"]
            else:
                sys.modules["cloud.app.models"] = previous_models

        self.assertTrue(session.committed)
        self.assertEqual(len(session.added), 1)
        event = session.added[0]
        self.assertIsNone(event.device_id)
        self.assertEqual(event.event_type, "gateway_online")
        self.assertEqual(event.payload["value"], "online")
        self.assertEqual(event.payload["gateway_id"], "gw-ubuntu-01")
        self.assertEqual(event.payload["source"], "gateway")


class _FakeEvent:
    def __init__(self, device_id, event_type, payload, occurred_at):
        self.device_id = device_id
        self.event_type = event_type
        self.payload = payload
        self.occurred_at = occurred_at


if __name__ == "__main__":
    unittest.main()


# ---------------------------------------------------------------------------
# Integration tests for sensor v2 ingest (use real async SQLite via conftest)
# ---------------------------------------------------------------------------

import pytest
import pytest_asyncio
from sqlalchemy import select

from cloud.app.models import Device, DeviceState, Event


def _make_run_async_for_test():
    """Return a _run_async replacement that stores the pending coroutine
    so the test can await it after the synchronous _handle_* call."""
    pending = []

    def _run(coro_func):
        pending.append(coro_func)

    return _run, pending


@pytest.mark.asyncio
async def test_handle_reported_sensor_kind2_stores_sensor_kind(db_session_factory):
    """sensor kind-2 reported message: device row gets sensor_kind=2."""
    service = MQTTService()
    service.set_db_session_factory(db_session_factory)

    _run, pending = _make_run_async_for_test()
    service._run_async = _run

    service._handle_reported(
        "sb/gw-1/devices/sensor/env-sensor-01/reported",
        {
            "ts": 1781431200000,
            "payload": {
                "sensor_kind": 2,
                "sensor": "environment",
                "state": {"temperature_c": 28.5, "humidity_percent": 48},
            },
        },
    )
    assert len(pending) == 1
    await pending[0]()

    async with db_session_factory() as s:
        device = (await s.execute(select(Device).where(Device.id == "env-sensor-01"))).scalar_one_or_none()
        assert device is not None
        assert device.device_type == "sensor"
        assert device.sensor_kind == 2

        state_row = (
            await s.execute(
                select(DeviceState)
                .where(DeviceState.device_id == "env-sensor-01")
                .order_by(DeviceState.reported_at.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        assert state_row is not None
        assert state_row.state["temperature_c"] == 28.5


@pytest.mark.asyncio
async def test_handle_event_sensor_occupancy_stores_device_state(db_session_factory):
    """sensor kind-1 occupancy event: DeviceState with occupancy is inserted."""
    from cloud.app.models import Home, Room

    async with db_session_factory() as s:
        s.add(Home(id="home-s", name="Sensor Home"))
        s.add(Room(id="room-s", home_id="home-s", name="Hallway"))
        s.add(Device(id="motion-sensor-01", device_type="sensor", sensor_kind=1, room_id="room-s", name="PIR"))
        await s.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)

    _run, pending = _make_run_async_for_test()
    service._run_async = _run

    service._handle_event(
        "sb/gw-1/devices/sensor/motion-sensor-01/event",
        {
            "ts": 1781431500000,
            "payload": {
                "sensor_kind": 1,
                "event": "occupancy_changed",
                "occupancy": "occupied",
            },
        },
    )
    assert len(pending) == 1
    await pending[0]()

    async with db_session_factory() as s:
        device = (await s.execute(select(Device).where(Device.id == "motion-sensor-01"))).scalar_one_or_none()
        assert device is not None
        # sensor_kind must remain the seeded value — the backfill guard
        # (`device.sensor_kind is None`) prevents overwriting an existing value.
        assert device.sensor_kind == 1

        state_row = (
            await s.execute(
                select(DeviceState)
                .where(DeviceState.device_id == "motion-sensor-01")
                .order_by(DeviceState.reported_at.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        assert state_row is not None
        assert state_row.state["occupancy"] == "occupied"


@pytest.mark.asyncio
async def test_handle_event_sensor_autoregisters_with_sensor_kind(db_session_factory):
    """sensor auto-register from event: Device row must have sensor_kind set."""
    # Use a device_id that does NOT exist in the DB yet.
    new_device_id = "pir-new-99"

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)

    _run, pending = _make_run_async_for_test()
    service._run_async = _run

    service._handle_event(
        f"sb/gw-1/devices/sensor/{new_device_id}/event",
        {
            "ts": 1781434800000,
            "payload": {
                "sensor_kind": 1,
                "event": "occupancy_changed",
                "occupancy": "occupied",
            },
        },
    )
    assert len(pending) == 1
    await pending[0]()

    async with db_session_factory() as s:
        device = (
            await s.execute(select(Device).where(Device.id == new_device_id))
        ).scalar_one_or_none()
        assert device is not None
        assert device.device_type == "sensor"
        assert device.sensor_kind == 1
