from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.auth import get_current_user
from cloud.app.database import get_db
from cloud.app.models import Command, Device, DeviceState, Event, Room, User
from cloud.app.schemas import DeviceOut, DeviceStateOut, DeviceUpdate

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


@router.patch("/{device_id}", response_model=DeviceOut)
async def update_device(
    device_id: str,
    body: DeviceUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update the user-facing device label only.

    Gateway identity remains the immutable device id / EUI64.
    """
    result = await db.execute(select(Device).where(Device.id == device_id))
    device = result.scalar_one_or_none()
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")
    if current_user.role != "admin":
        if device.room_id is not None:
            room = await db.get(Room, device.room_id)
            if room is None or room.home_id != current_user.home_id:
                raise HTTPException(status_code=403, detail="Device outside user home")
        elif current_user.home_id is None:
            raise HTTPException(status_code=403, detail="Device outside user home")

    device.name = body.name
    await db.commit()
    await db.refresh(device)
    return device


@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(
    device_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Delete a device and cascade-remove its states, events, and commands.

    Used to force a fresh re-pair from the gateway: after this returns 204,
    the next attribute report from the device will auto-pair it as a new row.
    """
    dev = await db.execute(select(Device).where(Device.id == device_id))
    if dev.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Device not found")

    await db.execute(delete(DeviceState).where(DeviceState.device_id == device_id))
    await db.execute(delete(Event).where(Event.device_id == device_id))
    await db.execute(delete(Command).where(Command.device_id == device_id))
    await db.execute(delete(Device).where(Device.id == device_id))
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
