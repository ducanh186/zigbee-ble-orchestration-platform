from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import is_admin
from cloud.app.auth import get_current_user
from cloud.app.database import get_db
from cloud.app.models import Room, User
from cloud.app.schemas import RoomOut

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
