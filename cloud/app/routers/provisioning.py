"""Provisioning session REST API.

SCRUM-71 covers REST persistence and validation only. Publishing
``gateway.prepare_join`` and processing replies are handled by SCRUM-72/73.
"""
from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.config import settings
from cloud.app.database import get_db
from cloud.app.models import Command, ProvisioningSession, Room
from cloud.app.mqtt_client import mqtt_service
from cloud.app.schemas import (
    ProvisioningErrorCode,
    ProvisioningSessionCreate,
    ProvisioningSessionOut,
)

router = APIRouter(prefix="/api/provisioning/sessions", tags=["provisioning"])

DEFAULT_PROVISIONING_DURATION_SEC = 180
DEFAULT_PREPARE_JOIN_TIMEOUT_MS = 5000
NON_TERMINAL_STATUSES = {"pending", "permit_open", "joining"}
TERMINAL_STATUSES = {"joined", "failed", "expired", "cancelled"}


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

    active = (
        await db.execute(
            select(ProvisioningSession).where(
                ProvisioningSession.eui64 == body.device.eui64,
                ProvisioningSession.status.in_(NON_TERMINAL_STATUSES),
            )
        )
    ).scalar_one_or_none()
    if active is not None:
        _raise_contract_error(
            409,
            ProvisioningErrorCode.SESSION_ALREADY_ACTIVE,
            f"active session already exists for eui64 '{body.device.eui64}'",
        )

    now = datetime.now(UTC).replace(tzinfo=None)
    command_id = uuid4().hex
    target = {
        "eui64": body.device.eui64,
        "install_code": body.device.install_code,
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
        install_code=body.device.install_code,
        device_type=body.device.device_type,
        model=body.device.model,
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
):
    return await _get_session_or_404(db, session_id)


@router.delete("/{session_id}", response_model=ProvisioningSessionOut)
async def cancel_provisioning_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
):
    session = await _get_session_or_404(db, session_id)
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
