"""Tests for SCRUM-70: provisioning_sessions model + schemas + enums.

Mirrors the contract in docs/PROVISIONING_CONTRACT.md. Schema-level only;
REST router is SCRUM-71, MQTT is SCRUM-72/73.
"""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from cloud.app.config import settings
from cloud.app.schemas import (
    ProvisioningDevicePayload,
    ProvisioningErrorCode,
    ProvisioningSessionCreate,
    ProvisioningSessionOut,
    ProvisioningStatus,
)
from cloud.tests.auth_helpers import create_auth_user, login_headers

VALID_EUI64 = "A8D417FEFF570B00"
VALID_INSTALL_CODE = "83FED3407A939723A5C639B26916D505C3B5"  # 36 hex = 18 bytes


# --- enums -----------------------------------------------------------------

def test_status_enum_values():
    assert {s.value for s in ProvisioningStatus} == {
        "pending",
        "permit_open",
        "joining",
        "joined",
        "failed",
        "expired",
        "cancelled",
    }


def test_error_code_enum_values():
    vals = {e.value for e in ProvisioningErrorCode}
    assert {
        "INVALID_QR_PAYLOAD",
        "INVALID_EUI64",
        "INVALID_INSTALL_CODE",
        "UNSUPPORTED_DEVICE_TYPE",
        "GATEWAY_NOT_FOUND",
        "ROOM_NOT_FOUND",
        "SESSION_ALREADY_ACTIVE",
    } <= vals


# --- device payload validation ---------------------------------------------

def test_device_payload_valid():
    p = ProvisioningDevicePayload(
        eui64=VALID_EUI64,
        install_code=VALID_INSTALL_CODE,
        device_type="light",
        model="EFR32MG12_LIGHT_KIT",
    )
    assert p.device_type == "light"
    assert p.model == "EFR32MG12_LIGHT_KIT"


def test_device_payload_model_optional():
    p = ProvisioningDevicePayload(
        eui64=VALID_EUI64, install_code=VALID_INSTALL_CODE, device_type="motion"
    )
    assert p.model is None


@pytest.mark.parametrize(
    "bad",
    ["xyz", "A8D4", "A8D417FEFF570B0", "GG" + "0" * 14, ""],
)
def test_device_payload_bad_eui64(bad):
    with pytest.raises(ValidationError):
        ProvisioningDevicePayload(
            eui64=bad, install_code=VALID_INSTALL_CODE, device_type="light"
        )


@pytest.mark.parametrize("bad", ["ZZZZ", "83FE", "abc", "12345"])
def test_device_payload_bad_install_code(bad):
    with pytest.raises(ValidationError):
        ProvisioningDevicePayload(
            eui64=VALID_EUI64, install_code=bad, device_type="light"
        )


@pytest.mark.parametrize("bad", ["occupancy", "occ", "lock", "unknown", "Light"])
def test_device_payload_bad_device_type(bad):
    with pytest.raises(ValidationError):
        ProvisioningDevicePayload(
            eui64=VALID_EUI64, install_code=VALID_INSTALL_CODE, device_type=bad
        )


# --- session create / out ---------------------------------------------------

def test_session_create_valid():
    body = ProvisioningSessionCreate(
        gateway_id="gw-ubuntu-01",
        room_id="room-1",
        device={
            "eui64": VALID_EUI64,
            "install_code": VALID_INSTALL_CODE,
            "device_type": "light",
            "model": "X",
        },
    )
    assert body.device.eui64 == VALID_EUI64
    assert body.gateway_id == "gw-ubuntu-01"


def test_session_out_never_exposes_install_code():
    assert "install_code" not in ProvisioningSessionOut.model_fields


# --- model persistence ------------------------------------------------------

@pytest.mark.asyncio
async def test_provisioning_session_persists(db_session_factory):
    from sqlalchemy import select

    from cloud.app.models import Home, ProvisioningSession, Room

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id="room-1", home_id="home-1", name="R"))
        s.add(
            ProvisioningSession(
                id="prov-1",
                gateway_id="gw-ubuntu-01",
                room_id="room-1",
                eui64=VALID_EUI64,
                install_code=VALID_INSTALL_CODE,
                device_type="light",
                model="EFR32MG12_LIGHT_KIT",
                status="pending",
            )
        )
        await s.commit()

        row = (
            await s.execute(
                select(ProvisioningSession).where(ProvisioningSession.id == "prov-1")
            )
        ).scalar_one()
        assert row.status == "pending"
        assert row.room_id == "room-1"
        assert row.eui64 == VALID_EUI64
        assert row.command_id is None


@pytest.mark.asyncio
async def test_session_out_maps_from_orm(db_session_factory):
    from cloud.app.models import ProvisioningSession

    row = ProvisioningSession(
        id="prov-9",
        gateway_id="gw-ubuntu-01",
        room_id="room-1",
        eui64=VALID_EUI64,
        install_code=VALID_INSTALL_CODE,
        device_type="light",
        status="pending",
    )
    out = ProvisioningSessionOut.model_validate(row)
    assert out.session_id == "prov-9"
    assert out.status == "pending"
    dumped = out.model_dump()
    assert "install_code" not in dumped
    assert dumped["session_id"] == "prov-9"


# --- REST API (SCRUM-71) -----------------------------------------------------

async def _seed_room(db_session_factory, room_id: str = "room-1"):
    from cloud.app.models import Home, Room

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id=room_id, home_id="home-1", name="R"))
        await s.commit()


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


def _create_body(**overrides):
    body = {
        "gateway_id": settings.gateway_id,
        "room_id": "room-1",
        "device": {
            "eui64": VALID_EUI64,
            "install_code": VALID_INSTALL_CODE,
            "device_type": "light",
            "model": "EFR32MG12_LIGHT_KIT",
        },
    }
    body.update(overrides)
    return body


@pytest.mark.asyncio
async def test_create_provisioning_session_api_persists_and_hides_install_code(
    client, db_session_factory, fake_mqtt
):
    from sqlalchemy import select

    from cloud.app.models import Command, ProvisioningSession

    await _seed_room(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)

    r = await client.post(
        "/api/provisioning/sessions", json=_create_body(), headers=headers
    )

    assert r.status_code == 201, r.text
    data = r.json()
    assert data["session_id"]
    assert data["status"] == "pending"
    assert data["gateway_id"] == settings.gateway_id
    assert data["room_id"] == "room-1"
    assert data["eui64"] == VALID_EUI64
    assert data["device_type"] == "light"
    assert data["model"] == "EFR32MG12_LIGHT_KIT"
    assert data["expires_at"] is not None
    assert "install_code" not in data
    assert len(fake_mqtt.published) == 1
    published = fake_mqtt.published[0]
    assert published["op"] == "gateway.prepare_join"
    assert published["device_id"] is None
    assert published["target"] == {
        "eui64": VALID_EUI64,
        "install_code": VALID_INSTALL_CODE,
        "duration_sec": 180,
    }
    assert published["timeout_ms"] == 5000

    async with db_session_factory() as s:
        row = (
            await s.execute(
                select(ProvisioningSession).where(
                    ProvisioningSession.id == data["session_id"]
                )
            )
        ).scalar_one()
        assert row.install_code == VALID_INSTALL_CODE
        assert row.status == "pending"
        assert row.command_id is not None
        command = await s.get(Command, row.command_id)
        assert command is not None
        assert command.target_kind == "gateway"
        assert command.op == "gateway.prepare_join"
        assert command.target == published["target"]
        assert command.status == "accepted"


@pytest.mark.asyncio
async def test_get_provisioning_session_api(client, db_session_factory):
    await _seed_room(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    created = (
        await client.post(
            "/api/provisioning/sessions", json=_create_body(), headers=headers
        )
    ).json()

    r = await client.get(
        f"/api/provisioning/sessions/{created['session_id']}",
        headers=headers,
    )

    assert r.status_code == 200, r.text
    data = r.json()
    assert data["session_id"] == created["session_id"]
    assert data["status"] == "pending"
    assert "install_code" not in data


@pytest.mark.asyncio
async def test_create_provisioning_session_unknown_gateway_404(
    client, db_session_factory, fake_mqtt
):
    headers = await _parent_headers(client, db_session_factory)

    r = await client.post(
        "/api/provisioning/sessions",
        json=_create_body(gateway_id="unknown-gateway"),
        headers=headers,
    )

    assert r.status_code == 404
    assert r.json()["detail"]["error_code"] == ProvisioningErrorCode.GATEWAY_NOT_FOUND
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_create_provisioning_session_unknown_room_404(
    client, db_session_factory, fake_mqtt
):
    headers = await _parent_headers(client, db_session_factory)

    r = await client.post(
        "/api/provisioning/sessions", json=_create_body(), headers=headers
    )

    assert r.status_code == 404
    assert r.json()["detail"]["error_code"] == ProvisioningErrorCode.ROOM_NOT_FOUND
    assert fake_mqtt.published == []


@pytest.mark.asyncio
async def test_create_provisioning_session_duplicate_active_409(
    client, db_session_factory, fake_mqtt
):
    await _seed_room(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    first = await client.post(
        "/api/provisioning/sessions", json=_create_body(), headers=headers
    )
    assert first.status_code == 201, first.text

    second = await client.post(
        "/api/provisioning/sessions", json=_create_body(), headers=headers
    )

    assert second.status_code == 409
    assert (
        second.json()["detail"]["error_code"]
        == ProvisioningErrorCode.SESSION_ALREADY_ACTIVE
    )
    assert len(fake_mqtt.published) == 1


@pytest.mark.asyncio
async def test_delete_provisioning_session_cancels_non_terminal(
    client, db_session_factory, fake_mqtt
):
    await _seed_room(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    created = (
        await client.post(
            "/api/provisioning/sessions", json=_create_body(), headers=headers
        )
    ).json()

    r = await client.delete(
        f"/api/provisioning/sessions/{created['session_id']}",
        headers=headers,
    )

    assert r.status_code == 200, r.text
    assert r.json()["status"] == "cancelled"
    assert len(fake_mqtt.published) == 1


@pytest.mark.asyncio
async def test_delete_provisioning_session_rejects_terminal(
    client, db_session_factory
):
    from cloud.app.models import Home, ProvisioningSession, Room

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id="room-1", home_id="home-1", name="R"))
        s.add(
            ProvisioningSession(
                id="prov-joined",
                gateway_id=settings.gateway_id,
                room_id="room-1",
                eui64=VALID_EUI64,
                install_code=VALID_INSTALL_CODE,
                device_type="light",
                status="joined",
            )
        )
        await s.commit()

    headers = await _parent_headers(client, db_session_factory)

    r = await client.delete(
        "/api/provisioning/sessions/prov-joined", headers=headers
    )

    assert r.status_code == 409


@pytest.mark.asyncio
async def test_prepare_join_reply_executed_marks_session_permit_open(
    db_session_factory,
):
    import asyncio

    from cloud.app.models import Command, Home, ProvisioningSession, Room
    from cloud.app.mqtt_client import MQTTService

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id="room-1", home_id="home-1", name="R"))
        s.add(
            Command(
                id="cmd-prepare",
                device_id=None,
                target_kind="gateway",
                op="gateway.prepare_join",
                target={
                    "eui64": VALID_EUI64,
                    "install_code": VALID_INSTALL_CODE,
                    "duration_sec": 180,
                },
                status="accepted",
                timeout_ms=5000,
            )
        )
        s.add(
            ProvisioningSession(
                id="prov-prepare",
                gateway_id=settings.gateway_id,
                room_id="room-1",
                eui64=VALID_EUI64,
                install_code=VALID_INSTALL_CODE,
                device_type="light",
                status="pending",
                command_id="cmd-prepare",
            )
        )
        await s.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []

    def run_in_test_loop(coro_func):
        tasks.append(asyncio.create_task(coro_func()))

    service._run_async = run_in_test_loop
    service._handle_command_reply(
        "sb/v1/hust/lab01/gw-ubuntu-01/commands/cmd-prepare/reply",
        {"payload": {"status": "executed"}},
    )
    await asyncio.gather(*tasks)

    async with db_session_factory() as s:
        session = await s.get(ProvisioningSession, "prov-prepare")
        command = await s.get(Command, "cmd-prepare")

    assert command.status == "executed"
    assert session.status == "permit_open"
    assert session.reason is None


@pytest.mark.asyncio
@pytest.mark.parametrize("reply_status", ["failed", "timeout"])
async def test_prepare_join_reply_failure_marks_session_failed(
    db_session_factory,
    reply_status,
):
    import asyncio

    from cloud.app.models import Command, Home, ProvisioningSession, Room
    from cloud.app.mqtt_client import MQTTService

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id="room-1", home_id="home-1", name="R"))
        s.add(
            Command(
                id=f"cmd-{reply_status}",
                device_id=None,
                target_kind="gateway",
                op="gateway.prepare_join",
                target={"eui64": VALID_EUI64},
                status="accepted",
                timeout_ms=5000,
            )
        )
        s.add(
            ProvisioningSession(
                id=f"prov-{reply_status}",
                gateway_id=settings.gateway_id,
                room_id="room-1",
                eui64=VALID_EUI64,
                install_code=VALID_INSTALL_CODE,
                device_type="light",
                status="pending",
                command_id=f"cmd-{reply_status}",
            )
        )
        await s.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []

    def run_in_test_loop(coro_func):
        tasks.append(asyncio.create_task(coro_func()))

    service._run_async = run_in_test_loop
    service._handle_command_reply(
        f"sb/v1/hust/lab01/gw-ubuntu-01/commands/cmd-{reply_status}/reply",
        {"payload": {"status": reply_status, "reason": "join failed"}},
    )
    await asyncio.gather(*tasks)

    async with db_session_factory() as s:
        session = await s.get(ProvisioningSession, f"prov-{reply_status}")

    assert session.status == "failed"
    assert session.reason == "join failed"


@pytest.mark.asyncio
async def test_gateway_provisioning_joined_marks_session_and_creates_device(
    db_session_factory,
):
    import asyncio

    from sqlalchemy import select

    from cloud.app.models import Device, Event, Home, ProvisioningSession, Room
    from cloud.app.mqtt_client import MQTTService

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id="room-1", home_id="home-1", name="R"))
        s.add(
            ProvisioningSession(
                id="prov-join",
                gateway_id=settings.gateway_id,
                room_id="room-1",
                eui64=VALID_EUI64,
                install_code=VALID_INSTALL_CODE,
                device_type="light",
                model="EFR32MG12_LIGHT_KIT",
                status="permit_open",
            )
        )
        await s.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []

    def run_in_test_loop(coro_func):
        tasks.append(asyncio.create_task(coro_func()))

    service._run_async = run_in_test_loop
    service._handle_gateway_event(
        {
            "schema": "sb.v1",
            "msg_id": "prov-joined-1",
            "ts": 1776064500000,
            "tenant_id": "hust",
            "site_id": "lab01",
            "gateway_id": settings.gateway_id,
            "source": "gateway",
            "payload": {
                "event": "provisioning_joined",
                "eui64": VALID_EUI64,
                "device_type": "light",
                "nwk_addr": "0x4F2A",
            },
        }
    )
    await asyncio.gather(*tasks)

    async with db_session_factory() as s:
        session = await s.get(ProvisioningSession, "prov-join")
        device = await s.get(Device, VALID_EUI64)
        events = (
            await s.execute(
                select(Event).where(Event.event_type == "provisioning_joined")
            )
        ).scalars().all()

    assert session.status == "joined"
    assert session.install_code == ""
    assert session.reason is None
    assert device is not None
    assert device.id == VALID_EUI64
    assert device.eui64 == VALID_EUI64
    assert device.device_type == "light"
    assert device.room_id == "room-1"
    assert device.is_online is True
    assert len(events) == 1


@pytest.mark.asyncio
async def test_gateway_provisioning_failed_marks_active_session_failed(
    db_session_factory,
):
    import asyncio

    from cloud.app.models import Home, ProvisioningSession, Room
    from cloud.app.mqtt_client import MQTTService

    async with db_session_factory() as s:
        s.add(Home(id="home-1", name="H"))
        s.add(Room(id="room-1", home_id="home-1", name="R"))
        s.add(
            ProvisioningSession(
                id="prov-fail",
                gateway_id=settings.gateway_id,
                room_id="room-1",
                eui64=VALID_EUI64,
                install_code=VALID_INSTALL_CODE,
                device_type="light",
                status="permit_open",
            )
        )
        await s.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []

    def run_in_test_loop(coro_func):
        tasks.append(asyncio.create_task(coro_func()))

    service._run_async = run_in_test_loop
    service._handle_gateway_event(
        {
            "schema": "sb.v1",
            "msg_id": "prov-failed-1",
            "ts": 1776064500000,
            "tenant_id": "hust",
            "site_id": "lab01",
            "gateway_id": settings.gateway_id,
            "source": "gateway",
            "payload": {
                "event": "provisioning_failed",
                "eui64": VALID_EUI64,
                "reason": "install code rejected",
            },
        }
    )
    await asyncio.gather(*tasks)

    async with db_session_factory() as s:
        session = await s.get(ProvisioningSession, "prov-fail")

    assert session.status == "failed"
    assert session.reason == "install code rejected"
