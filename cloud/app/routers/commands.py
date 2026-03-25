from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.database import get_db
from cloud.app.models import Command, Device
from cloud.app.mqtt_client import mqtt_service
from cloud.app.schemas import CommandCreate, CommandOut

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
):
    # Verify device exists
    result = await db.execute(select(Device).where(Device.id == device_id))
    if result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Device not found")

    command_id = uuid4().hex
    cmd = Command(
        id=command_id,
        device_id=device_id,
        op=body.op,
        target=body.target,
        status="accepted",
    )
    db.add(cmd)
    await db.commit()
    await db.refresh(cmd)

    # Publish command request to MQTT
    mqtt_service.publish_command(
        command_id=command_id,
        device_id=device_id,
        op=body.op,
        target=body.target,
        timeout_ms=body.timeout_ms,
    )

    return cmd


@router.get("/commands/{command_id}", response_model=CommandOut)
async def get_command(
    command_id: str,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Command).where(Command.id == command_id))
    cmd = result.scalar_one_or_none()
    if cmd is None:
        raise HTTPException(status_code=404, detail="Command not found")
    return cmd
