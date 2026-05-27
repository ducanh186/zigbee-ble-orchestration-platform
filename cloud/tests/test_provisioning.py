"""Tests for SCRUM-70: provisioning_sessions model + schemas + enums.

Mirrors the contract in docs/PROVISIONING_CONTRACT.md. Schema-level only;
REST router is SCRUM-71, MQTT is SCRUM-72/73.
"""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from cloud.app.schemas import (
    ProvisioningDevicePayload,
    ProvisioningErrorCode,
    ProvisioningSessionCreate,
    ProvisioningSessionOut,
    ProvisioningStatus,
)

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
