"""Shared pytest fixtures for cloud tests.

Strategy: run against an in-memory sqlite+aiosqlite database, and replace
the MQTT publisher with an in-process fake so tests never touch a broker.
"""
from __future__ import annotations

import os

# Force sqlite before cloud modules import and instantiate the engine.
os.environ.setdefault("SB_DATABASE_URL", "sqlite+aiosqlite:///:memory:")

import asyncio  # noqa: E402
from typing import Any  # noqa: E402

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine


class FakeMQTTPublisher:
    """Captures publish_command calls; satisfies the attribute surface used by routers."""

    def __init__(self) -> None:
        self.published: list[dict[str, Any]] = []
        self._db_session_factory = None

    def set_db_session_factory(self, factory) -> None:
        self._db_session_factory = factory

    def connect(self) -> None:  # noqa: D401
        return None

    def disconnect(self) -> None:
        return None

    def publish_command(
        self,
        command_id: str,
        device_id: str,
        op: str,
        target: dict,
        timeout_ms: int | None = 5000,
    ) -> None:
        self.published.append(
            {
                "command_id": command_id,
                "device_id": device_id,
                "op": op,
                "target": target,
                "timeout_ms": timeout_ms,
            }
        )

    def publish_gateway_command(
        self,
        command_id: str,
        op: str,
        target: dict,
        timeout_ms: int | None = 5000,
    ) -> None:
        self.published.append(
            {
                "command_id": command_id,
                "device_id": None,
                "op": op,
                "target": target,
                "timeout_ms": timeout_ms,
            }
        )

    def publish_automation_rule(
        self,
        automation_id: str,
        payload: dict[str, Any],
        *,
        deleted: bool = False,
    ) -> None:
        self.published.append(
            {
                "topic": (
                    f"sb/v1/hust/lab01/gw-ubuntu-01/desired/automation/{automation_id}"
                ),
                "qos": 0,
                "retain": True,
                "payload": {
                    "schema": "sb.v1",
                    "tenant_id": "hust",
                    "site_id": "lab01",
                    "gateway_id": "gw-ubuntu-01",
                    "source": "cloud",
                    "payload": payload | {"deleted": deleted},
                },
            }
        )


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def db_session_factory(monkeypatch):
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    # Patch cloud.app.database so routers and workers use this engine
    import cloud.app.database as dbmod
    from cloud.app.database import Base
    # Ensure all model classes are registered on Base.metadata before
    # create_all -- otherwise running a test file in isolation may miss
    # tables that only get loaded transitively by other files.
    import cloud.app.models  # noqa: F401

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    monkeypatch.setattr(dbmod, "engine", engine)
    monkeypatch.setattr(dbmod, "async_session", factory)

    async def _noop_init_db():
        return None

    monkeypatch.setattr(dbmod, "init_db", _noop_init_db)

    yield factory
    await engine.dispose()


@pytest_asyncio.fixture
async def fake_mqtt(monkeypatch):
    fake = FakeMQTTPublisher()
    import cloud.app.mqtt_client as mqttmod
    import cloud.app.routers.automations as automod
    import cloud.app.routers.commands as cmdmod
    import cloud.app.routers.gateways as gwmod
    import cloud.app.routers.provisioning as provmod

    monkeypatch.setattr(mqttmod, "mqtt_service", fake)
    monkeypatch.setattr(automod, "mqtt_service", fake)
    monkeypatch.setattr(cmdmod, "mqtt_service", fake)
    monkeypatch.setattr(gwmod, "mqtt_service", fake)
    monkeypatch.setattr(provmod, "mqtt_service", fake)
    yield fake


@pytest_asyncio.fixture
async def client(db_session_factory, fake_mqtt):
    # Import lazily so monkeypatches apply.
    from cloud.app.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        # Lifespan started by ASGI transport; ensure device seed is easy via DB.
        yield c


@pytest_asyncio.fixture
async def seed_light(db_session_factory):
    from cloud.app.models import Device, Home, Room

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="Test Home"))
        s.add(Room(id="room-1", home_id="home-1", name="Living"))
        s.add(
            Device(
                id="light-01",
                device_type="light",
                eui64="00124b0001aa22bb",
                room_id="room-1",
                name="Main Light",
                is_online=True,
            )
        )
        await s.commit()
    return "light-01"


@pytest_asyncio.fixture
async def seed_switch(db_session_factory):
    from cloud.app.models import Device, Home, Room

    async with db_session_factory() as s:
        # Reuse home/room if already created by seed_light in the same test
        from sqlalchemy import select
        if not (await s.execute(select(Home).where(Home.id == "home-1"))).scalar():
            s.add(Home(id="home-1", name="Test Home"))
            s.add(Room(id="room-1", home_id="home-1", name="Living"))
        s.add(
            Device(
                id="switch-01",
                device_type="switch",
                room_id="room-1",
                name="Wall Switch",
                is_online=True,
            )
        )
        await s.commit()
    return "switch-01"
