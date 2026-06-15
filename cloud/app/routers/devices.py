import logging

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import (
    ensure_room_visible,
    get_manageable_device_or_404,
    get_visible_device_or_404,
    visible_device_clause,
)
from cloud.app.auth import get_current_user, require_parent_or_admin
from cloud.app.command_execution import CommandExecutionError, execute_device_command
from cloud.app.database import get_db
from cloud.app.models import Command, Device, DeviceState, Event, Room, User
from cloud.app.schemas import DeviceOut, DeviceStateOut, DeviceUpdate

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/devices", tags=["devices"])


@router.get("/", response_model=list[DeviceOut])
async def list_devices(
    room_id: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all devices, optionally filtered by room_id.

    The latest reported state for each device is inlined into the response
    (`state` + `reported_at`) so the app fetches everything in one round-trip
    instead of an N+1 fan-out to `/devices/{id}/state`.
    """
    stmt = select(Device).outerjoin(Room, Device.room_id == Room.id)
    clause = visible_device_clause(current_user)
    if clause is not None:
        stmt = stmt.where(clause)
    if room_id is not None:
        stmt = stmt.where(Device.room_id == room_id)
    result = await db.execute(stmt)
    devices = result.scalars().all()

    # One extra query for the latest DeviceState per device (window function),
    # then merge in Python — keeps this O(1) round-trips, not O(devices).
    device_ids = [d.id for d in devices]
    state_map: dict[str, tuple[dict, object]] = {}
    if device_ids:
        ranked = (
            select(
                DeviceState.device_id,
                DeviceState.state,
                DeviceState.reported_at,
                func.row_number()
                .over(
                    partition_by=DeviceState.device_id,
                    order_by=DeviceState.reported_at.desc(),
                )
                .label("rn"),
            )
            .where(DeviceState.device_id.in_(device_ids))
            .subquery()
        )
        latest = await db.execute(select(ranked).where(ranked.c.rn == 1))
        for row in latest:
            state_map[row.device_id] = (row.state, row.reported_at)

    for device in devices:
        latest_state = state_map.get(device.id)
        # Attach as plain attributes so DeviceOut (from_attributes) picks them up.
        device.state = latest_state[0] if latest_state else None
        device.reported_at = latest_state[1] if latest_state else None

    return devices


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
    """Update the user-facing device label, and optionally move it to a room.

    Gateway identity remains the immutable device id / EUI64. When `room_id`
    is provided it must reference a room in the caller's home.
    """
    device = await get_manageable_device_or_404(db, device_id, current_user)
    if body.name is not None:
        device.name = body.name
    if body.room_id is not None:
        room = await db.get(Room, body.room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Room not found")
        await ensure_room_visible(db, room, current_user)
        device.room_id = body.room_id
    await db.commit()
    await db.refresh(device)
    if body.room_id is not None:
        # The DB is the source of truth for room; pushing device.set_room to the
        # gateway is a best-effort side effect (the gateway keeps room in RAM and
        # is re-synced on its next online event). A publish failure must not fail
        # the PATCH whose DB write already succeeded.
        try:
            await execute_device_command(
                db,
                device_id=device_id,
                op="device.set_room",
                target={"room_id": body.room_id},
                timeout_ms=5000,
                current_user=current_user,
            )
        except CommandExecutionError:
            logger.exception(
                "device.set_room publish failed for %s; room committed, "
                "gateway will resync on next online",
                device_id,
            )
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
