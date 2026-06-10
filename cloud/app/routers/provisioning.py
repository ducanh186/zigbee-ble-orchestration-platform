"""Provisioning session REST API.

SCRUM-71 covers REST persistence and validation only. Publishing
``gateway.prepare_join`` and processing replies are handled by SCRUM-72/73.
"""
from __future__ import annotations

import io
import json
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Response, status
import qrcode
import qrcode.image.svg
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import (
    ensure_provisioning_session_visible,
    ensure_room_visible,
)
from cloud.app.auth import get_current_user, require_admin, require_parent_or_admin
from cloud.app.config import settings
from cloud.app.database import get_db
from cloud.app.models import Command, FactoryDevice, ProvisioningSession, Room, User
from cloud.app.mqtt_client import mqtt_service
from cloud.app.schemas import (
    FactoryDeviceOut,
    FactoryDeviceRegister,
    ProvisioningErrorCode,
    ProvisioningLabelCreate,
    ProvisioningLabelOut,
    ProvisioningSessionCreate,
    ProvisioningSessionOut,
)

router = APIRouter(prefix="/api/provisioning/sessions", tags=["provisioning"])
labels_router = APIRouter(prefix="/api/provisioning/labels", tags=["provisioning"])
factory_devices_router = APIRouter(
    prefix="/api/provisioning/factory-devices", tags=["provisioning"]
)


def _factory_device_out(device: FactoryDevice) -> FactoryDeviceOut:
    return FactoryDeviceOut(
        eui64=device.eui64,
        device_type=device.device_type,
        model=device.model,
        is_active=device.is_active,
        has_install_code=bool(device.install_code),
    )


@factory_devices_router.post(
    "",
    response_model=FactoryDeviceOut,
    status_code=status.HTTP_201_CREATED,
)
async def register_factory_device(
    body: FactoryDeviceRegister,
    response: Response,
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_parent_or_admin),
):
    """Idempotent upsert of a factory device + its (CRC-validated) install code.

    The raw install code is stored but never logged or returned.
    """
    device = await db.get(FactoryDevice, body.eui64)
    if device is None:
        device = FactoryDevice(
            eui64=body.eui64,
            install_code=body.install_code,
            device_type=body.device_type,
            model=body.model,
            is_active=True,
        )
        db.add(device)
    else:
        device.install_code = body.install_code
        device.device_type = body.device_type
        device.model = body.model
        device.is_active = True
        response.status_code = status.HTTP_200_OK
    await db.commit()
    await db.refresh(device)
    return _factory_device_out(device)


@factory_devices_router.get("", response_model=list[FactoryDeviceOut])
async def list_factory_devices(
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_parent_or_admin),
):
    """List factory devices without exposing raw install codes (proof-in-DB)."""
    rows = (
        await db.execute(select(FactoryDevice).order_by(FactoryDevice.eui64))
    ).scalars().all()
    return [_factory_device_out(row) for row in rows]

DEFAULT_PROVISIONING_DURATION_SEC = 180
DEFAULT_PREPARE_JOIN_TIMEOUT_MS = 5000
NON_TERMINAL_STATUSES = {"pending", "permit_open", "joining"}
TERMINAL_STATUSES = {"joined", "failed", "expired", "cancelled"}


def _qr_svg(payload_json: str) -> str:
    image = qrcode.make(
        payload_json,
        image_factory=qrcode.image.svg.SvgPathImage,
        border=2,
    )
    buf = io.BytesIO()
    image.save(buf)
    return buf.getvalue().decode("utf-8")


@labels_router.post(
    "",
    response_model=ProvisioningLabelOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_provisioning_label(
    body: ProvisioningLabelCreate,
    _admin=Depends(require_admin),
):
    payload = {
        "version": 1,
        "eui64": body.eui64,
        "device_type": body.device_type,
    }
    payload_json = json.dumps(payload, separators=(",", ":"))
    return {
        "payload": payload,
        "payload_json": payload_json,
        "qr_svg": _qr_svg(payload_json),
    }


def _raise_contract_error(
    status_code: int,
    error_code: ProvisioningErrorCode,
    message: str,
) -> None:
    raise HTTPException(
        status_code=status_code,
        detail={"error_code": error_code.value, "message": message},
    )


async def _get_session_or_404(
    db: AsyncSession,
    session_id: str,
) -> ProvisioningSession:
    result = await db.execute(
        select(ProvisioningSession).where(ProvisioningSession.id == session_id)
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise HTTPException(status_code=404, detail="Provisioning session not found")
    return session


@router.post(
    "",
    response_model=ProvisioningSessionOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_provisioning_session(
    body: ProvisioningSessionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    if body.gateway_id != settings.gateway_id:
        _raise_contract_error(
            404,
            ProvisioningErrorCode.GATEWAY_NOT_FOUND,
            f"unknown gateway_id '{body.gateway_id}'",
        )

    room = (
        await db.execute(select(Room).where(Room.id == body.room_id))
    ).scalar_one_or_none()
    if room is None:
        _raise_contract_error(
            404,
            ProvisioningErrorCode.ROOM_NOT_FOUND,
            f"room_id '{body.room_id}' not found",
        )
    await ensure_room_visible(db, room, current_user)

    now = datetime.now(UTC).replace(tzinfo=None)
    active_sessions = (
        await db.execute(
            select(ProvisioningSession).where(
                ProvisioningSession.eui64 == body.device.eui64,
                ProvisioningSession.status.in_(NON_TERMINAL_STATUSES),
            )
        )
    ).scalars().all()
    blocking = None
    for sess in active_sessions:
        # Auto-expire stale non-terminal sessions so a lapsed permit window
        # does not block re-provisioning the same device with a 409.
        if sess.expires_at is not None and sess.expires_at <= now:
            sess.status = "expired"
        else:
            blocking = sess
    if blocking is not None:
        _raise_contract_error(
            409,
            ProvisioningErrorCode.SESSION_ALREADY_ACTIVE,
            f"active session already exists for eui64 '{body.device.eui64}'",
        )

    factory_device = await db.get(FactoryDevice, body.device.eui64)
    if factory_device is None or not factory_device.is_active:
        _raise_contract_error(
            404,
            ProvisioningErrorCode.DEVICE_NOT_FACTORY_REGISTERED,
            f"device eui64 '{body.device.eui64}' is not factory registered",
        )
    if factory_device.device_type != body.device.device_type:
        _raise_contract_error(
            422,
            ProvisioningErrorCode.INVALID_QR_PAYLOAD,
            "device_type does not match factory registry",
        )

    command_id = uuid4().hex
    target = {
        "eui64": body.device.eui64,
        "install_code": factory_device.install_code,
        "duration_sec": DEFAULT_PROVISIONING_DURATION_SEC,
    }
    command = Command(
        id=command_id,
        device_id=None,
        target_kind="gateway",
        op="gateway.prepare_join",
        target=target,
        status="accepted",
        timeout_ms=DEFAULT_PREPARE_JOIN_TIMEOUT_MS,
        expires_at=now + timedelta(milliseconds=DEFAULT_PREPARE_JOIN_TIMEOUT_MS),
    )
    session = ProvisioningSession(
        id=uuid4().hex,
        gateway_id=body.gateway_id,
        room_id=body.room_id,
        eui64=body.device.eui64,
        install_code=factory_device.install_code,
        device_type=factory_device.device_type,
        model=factory_device.model,
        status="pending",
        command_id=command_id,
        expires_at=now + timedelta(seconds=DEFAULT_PROVISIONING_DURATION_SEC),
    )
    db.add(command)
    db.add(session)
    await db.commit()
    await db.refresh(session)

    mqtt_service.publish_gateway_command(
        command_id=command_id,
        op="gateway.prepare_join",
        target=target,
        timeout_ms=DEFAULT_PREPARE_JOIN_TIMEOUT_MS,
    )
    return session


@router.get("/{session_id}", response_model=ProvisioningSessionOut)
async def get_provisioning_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = await _get_session_or_404(db, session_id)
    await ensure_provisioning_session_visible(db, session, current_user)
    return session


@router.delete("/{session_id}", response_model=ProvisioningSessionOut)
async def cancel_provisioning_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    session = await _get_session_or_404(db, session_id)
    await ensure_provisioning_session_visible(db, session, current_user)
    if session.status in TERMINAL_STATUSES:
        raise HTTPException(
            status_code=409,
            detail="Provisioning session is already terminal",
        )

    session.status = "cancelled"
    session.updated_at = datetime.now(UTC).replace(tzinfo=None)
    await db.commit()
    await db.refresh(session)
    return session
