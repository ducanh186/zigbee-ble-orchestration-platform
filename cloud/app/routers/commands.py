from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from pydantic import ValidationError

from cloud.app.access_control import (
    ensure_device_visible,
    get_visible_device_or_404,
    is_admin,
)
from cloud.app.auth import get_current_user, require_operator
from cloud.app.database import get_db
from cloud.app.models import Command, Device, User
from cloud.app.mqtt_client import mqtt_service
from cloud.app.schemas import CommandCreate, CommandOut, translate_command_for_gateway

router = APIRouter(prefix="/api", tags=["commands"])


@router.post(
    "/devices/{device_id}/command",
    response_model=CommandOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_command(
    device_id: str,
    body: CommandCreate,
    db: AsyncSession = Depends(get_db),
    operator: User = Depends(require_operator),
):
    # Verify device exists and get its type for command translation
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")
    await ensure_device_visible(db, device, operator)

    # Translate user-friendly format to gateway wire format
    try:
        mqtt_op, mqtt_target = translate_command_for_gateway(
            device.device_type, body.op, body.target
        )
    except (ValueError, ValidationError) as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    command_id = uuid4().hex
    timeout_ms = body.timeout_ms or 5000
    expires_at = datetime.now(UTC).replace(tzinfo=None) + timedelta(
        milliseconds=timeout_ms
    )
    cmd = Command(
        id=command_id,
        device_id=device_id,
        op=mqtt_op,
        target=mqtt_target,
        status="accepted",
        timeout_ms=timeout_ms,
        expires_at=expires_at,
    )
    db.add(cmd)
    await db.commit()
    await db.refresh(cmd)

    # Publish command request to MQTT
    mqtt_service.publish_command(
        command_id=command_id,
        device_id=device_id,
        op=mqtt_op,
        target=mqtt_target,
        timeout_ms=timeout_ms,
    )

    return cmd


@router.get("/commands/{command_id}", response_model=CommandOut)
async def get_command(
    command_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Command).where(Command.id == command_id))
    cmd = result.scalar_one_or_none()
    if cmd is None:
        raise HTTPException(status_code=404, detail="Command not found")
    if cmd.device_id is None:
        if not is_admin(current_user):
            raise HTTPException(status_code=403, detail="Command outside user home")
    else:
        await get_visible_device_or_404(db, cmd.device_id, current_user)
    return cmd
