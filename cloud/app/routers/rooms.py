from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import ensure_room_visible, is_admin
from cloud.app.auth import get_current_user, require_parent_or_admin
from cloud.app.database import get_db
from cloud.app.models import Device, Room, User
from cloud.app.schemas import RoomCreate, RoomOut, RoomUpdate

router = APIRouter(prefix="/api/rooms", tags=["rooms"])


@router.get("/", response_model=list[RoomOut])
async def list_rooms(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List rooms in the current user's home. Admins see every room."""
    stmt = select(Room)
    if not is_admin(current_user):
        if current_user.home_id is None:
            return []
        stmt = stmt.where(Room.home_id == current_user.home_id)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("/", response_model=RoomOut)
async def create_room(
    body: RoomCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    if current_user.home_id is None:
        raise HTTPException(status_code=400, detail="User has no home")

    room = Room(
        id=f"room_{uuid4().hex[:8]}",
        home_id=current_user.home_id,
        name=body.name,
    )
    db.add(room)
    await db.commit()
    await db.refresh(room)
    return room


@router.patch("/{room_id}", response_model=RoomOut)
async def rename_room(
    room_id: str,
    body: RoomUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    room = await db.get(Room, room_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    await ensure_room_visible(db, room, current_user)

    room.name = body.name
    await db.commit()
    await db.refresh(room)
    return room


@router.delete("/{room_id}", response_model=RoomOut)
async def delete_room(
    room_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_parent_or_admin),
):
    room = await db.get(Room, room_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    await ensure_room_visible(db, room, current_user)

    devices = await db.execute(select(Device.id).where(Device.room_id == room_id))
    if devices.scalars().first() is not None:
        raise HTTPException(status_code=409, detail="Room not empty")

    response = RoomOut.model_validate(room)
    await db.delete(room)
    await db.commit()
    return response
