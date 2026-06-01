"""Tests for MQTT ingestion side effects."""
from __future__ import annotations

import asyncio
from types import SimpleNamespace

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine


@pytest.mark.asyncio
async def test_handle_motion_event_auto_registers_and_persists():
    from cloud.app.database import Base
    from cloud.app.models import Device, Event
    from cloud.app.mqtt_client import MQTTService

    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    db_session_factory = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []

    def run_in_test_loop(coro_func):
        tasks.append(asyncio.create_task(coro_func()))

    service._run_async = run_in_test_loop

    device_id = "00124b0001aa22cc"
    topic = f"sb/v1/hust/lab01/gw-ubuntu-01/devices/motion/{device_id}/event"
    service._handle_event(
        topic,
        {
            "schema": "sb.v1",
            "msg_id": "motion-event-1",
            "ts": 1776064500000,
            "tenant_id": "hust",
            "site_id": "lab01",
            "gateway_id": "gw-ubuntu-01",
            "source": "gateway",
            "payload": {
                "device_id": device_id,
                "device_type": "motion",
                "event": "occupancy_changed",
                "occupancy": "occupied",
                "eui64": device_id,
                "nwk_addr": "0x4F2A",
                "raw": "0x01",
            },
        },
    )
    await tasks[0]

    deadline = asyncio.get_running_loop().time() + 1.0
    event = None
    device = None
    while asyncio.get_running_loop().time() < deadline:
        async with db_session_factory() as session:
            event = (
                await session.execute(select(Event).where(Event.device_id == device_id))
            ).scalar_one_or_none()
            device = await session.get(Device, device_id)
        if event and device:
            break
        await asyncio.sleep(0.01)

    assert device is not None
    assert device.device_type == "motion"
    assert event is not None
    assert event.event_type == "occupancy_changed"
    assert event.payload["occupancy"] == "occupied"

    await engine.dispose()


@pytest.mark.asyncio
async def test_connect_configures_tls_and_mtls_when_enabled(monkeypatch):
    from cloud.app import mqtt_client as mqtt_module

    class FakeClient:
        def __init__(self, *args, **kwargs):
            self.username = None
            self.password = None
            self.tls_kwargs = None
            self.connect_args = None
            self.loop_started = False

        def username_pw_set(self, username, password):
            self.username = username
            self.password = password

        def tls_set(self, **kwargs):
            self.tls_kwargs = kwargs

        def connect(self, host, port):
            self.connect_args = (host, port)

        def loop_start(self):
            self.loop_started = True

    fake_client = FakeClient()
    monkeypatch.setattr(
        mqtt_module.mqtt,
        "Client",
        lambda *args, **kwargs: fake_client,
    )

    service = mqtt_module.MQTTService()
    service.settings = SimpleNamespace(
        mqtt_host="mosquitto",
        mqtt_port=8883,
        mqtt_username="client",
        mqtt_password="client-pass",
        mqtt_tls_enabled=True,
        mqtt_mtls_enabled=True,
        mqtt_ca_cert_path="/mosquitto/certs/ca.crt",
        mqtt_client_cert_path="/mosquitto/certs/clients/cloud.crt",
        mqtt_client_key_path="/mosquitto/certs/clients/cloud.key",
        tenant_id="hust",
        site_id="lab01",
        gateway_id="gw-ubuntu-01",
    )

    service.connect()

    assert fake_client.username == "client"
    assert fake_client.password == "client-pass"
    assert fake_client.tls_kwargs == {
        "ca_certs": "/mosquitto/certs/ca.crt",
        "certfile": "/mosquitto/certs/clients/cloud.crt",
        "keyfile": "/mosquitto/certs/clients/cloud.key",
    }
    assert fake_client.connect_args == ("mosquitto", 8883)
    assert fake_client.loop_started is True


@pytest.mark.asyncio
async def test_command_reply_does_not_regress_terminal_status():
    from cloud.app.database import Base
    from cloud.app.models import Command, Device, Home, Room
    from cloud.app.mqtt_client import MQTTService

    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    db_session_factory = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []

    def run_in_test_loop(coro_func):
        tasks.append(asyncio.create_task(coro_func()))

    service._run_async = run_in_test_loop

    async with db_session_factory() as session:
        session.add(Home(id="home-1", name="Test Home"))
        session.add(Room(id="room-1", home_id="home-1", name="Living"))
        session.add(
            Device(
                id="light-01",
                device_type="light",
                room_id="room-1",
                name="Main Light",
            )
        )
        session.add(
            Command(
                id="cmd-1",
                device_id="light-01",
                op="device.command",
                target={"command": "off"},
                status="accepted",
                timeout_ms=5000,
            )
        )
        await session.commit()

    topic = "sb/v1/hust/lab01/gw-ubuntu-01/commands/cmd-1/reply"
    service._handle_command_reply(
        topic,
        {
            "payload": {
                "status": "executed",
            },
        },
    )
    service._handle_command_reply(
        topic,
        {
            "payload": {
                "status": "sent",
            },
        },
    )
    await asyncio.gather(*tasks)

    async with db_session_factory() as session:
        command = await session.get(Command, "cmd-1")

    assert command is not None
    assert command.status == "executed"

    await engine.dispose()


@pytest.mark.asyncio
async def test_gateway_event_updates_automation_sync_and_execution_state():
    from cloud.app.database import Base
    from cloud.app.models import Automation, Event
    from cloud.app.mqtt_client import MQTTService

    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    db_session_factory = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []

    def run_in_test_loop(coro_func):
        tasks.append(asyncio.create_task(coro_func()))

    service._run_async = run_in_test_loop

    async with db_session_factory() as session:
        session.add(
            Automation(
                id="rule-01",
                name="Motion turns on light",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                version=1,
                trigger={
                    "device_id": "motion-01",
                    "device_type": "motion",
                    "event": "occupancy_changed",
                    "state": {"occupancy": "occupied"},
                },
                actions=[
                    {
                        "device_id": "light-01",
                        "device_type": "light",
                        "command": "on",
                    }
                ],
                sync_status="pending",
                last_run_status="never_run",
                last_error=None,
            )
        )
        await session.commit()

    service._handle_gateway_event(
        {
            "schema": "sb.v1",
            "msg_id": "gw-event-1",
            "ts": 1776064500000,
            "tenant_id": "hust",
            "site_id": "lab01",
            "gateway_id": "gw-ubuntu-01",
            "source": "gateway",
            "payload": {
                "event": "automation_synced",
                "rule_id": "rule-01",
                "version": 1,
                "result": "ok",
            },
        }
    )
    service._handle_gateway_event(
        {
            "schema": "sb.v1",
            "msg_id": "gw-event-2",
            "ts": 1776064500500,
            "tenant_id": "hust",
            "site_id": "lab01",
            "gateway_id": "gw-ubuntu-01",
            "source": "gateway",
            "payload": {
                "event": "automation_executed",
                "rule_id": "rule-01",
                "version": 1,
                "result": "ok",
                "trigger_device_id": "motion-01",
                "target_device_id": "light-01",
            },
        }
    )
    await asyncio.gather(*tasks)

    async with db_session_factory() as session:
        rule = await session.get(Automation, "rule-01")
        events = (
            await session.execute(
                select(Event).order_by(Event.occurred_at.asc())
            )
        ).scalars().all()

    assert rule is not None
    assert rule.sync_status == "synced"
    assert rule.last_run_status == "executed"
    assert [event.event_type for event in events] == [
        "automation_synced",
        "automation_executed",
    ]

    await engine.dispose()
