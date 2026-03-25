from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.database import get_db
from cloud.app.models import Device, DeviceState
from cloud.app.schemas import DeviceOut, DeviceStateOut

router = APIRouter(prefix="/api/devices", tags=["devices"])


@router.get("/", response_model=list[DeviceOut])
async def list_devices(
    room_id: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
):
    """List all devices, optionally filtered by room_id."""
    stmt = select(Device)
    if room_id is not None:
        stmt = stmt.where(Device.room_id == room_id)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{device_id}", response_model=DeviceOut)
async def get_device(
    device_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get a single device by its device_id."""
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")
    return device


@router.get("/{device_id}/state", response_model=DeviceStateOut)
async def get_device_state(
    device_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get the latest reported state for a device."""
    # Verify device exists
    dev_result = await db.execute(select(Device).where(Device.id == device_id))
    if dev_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Device not found")

    stmt = (
        select(DeviceState)
        .where(DeviceState.device_id == device_id)
        .order_by(DeviceState.reported_at.desc())
        .limit(1)
    )
    result = await db.execute(stmt)
    state = result.scalar_one_or_none()
    if state is None:
        raise HTTPException(status_code=404, detail="No state reported for this device")
    return state
