from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import (
    get_manageable_device_or_404,
    get_visible_device_or_404,
    visible_device_clause,
)
from cloud.app.auth import get_current_user, require_parent_or_admin
from cloud.app.database import get_db
from cloud.app.models import Command, Device, DeviceState, Event, Room, User
from cloud.app.schemas import DeviceOut, DeviceStateOut, DeviceUpdate

router = APIRouter(prefix="/api/devices", tags=["devices"])


@router.get("/", response_model=list[DeviceOut])
async def list_devices(
    room_id: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all devices, optionally filtered by room_id."""
    stmt = select(Device).outerjoin(Room, Device.room_id == Room.id)
    clause = visible_device_clause(current_user)
    if clause is not None:
        stmt = stmt.where(clause)
    if room_id is not None:
        stmt = stmt.where(Device.room_id == room_id)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{device_id}", response_model=DeviceOut)
async def get_device(
    device_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a single device by its device_id."""
    return await get_visible_device_or_404(db, device_id, current_user)


@router.get("/{device_id}/state", response_model=DeviceStateOut)
async def get_device_state(
    device_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get the latest reported state for a device."""
    await get_visible_device_or_404(db, device_id, current_user)

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
    current_user: User = Depends(require_parent_or_admin),
):
    """Update the user-facing device label only.

    Gateway identity remains the immutable device id / EUI64.
    """
    device = await get_manageable_device_or_404(db, device_id, current_user)
    device.name = body.name
    await db.commit()
    await db.refresh(device)
    return device


@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(
    device_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    """Delete a device and cascade-remove its states, events, and commands.

    Used to force a fresh re-pair from the gateway: after this returns 204,
    the next attribute report from the device will auto-pair it as a new row.
    """
    await get_manageable_device_or_404(db, device_id, current_user)

    await db.execute(delete(DeviceState).where(DeviceState.device_id == device_id))
    await db.execute(delete(Event).where(Event.device_id == device_id))
    await db.execute(delete(Command).where(Command.device_id == device_id))
    await db.execute(delete(Device).where(Device.id == device_id))
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
