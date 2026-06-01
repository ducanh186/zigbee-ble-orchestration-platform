from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import is_admin, visible_device_ids
from cloud.app.auth import get_current_user
from cloud.app.database import get_db
from cloud.app.models import Event, User
from cloud.app.schemas import EventOut

router = APIRouter(prefix="/api/events", tags=["events"])


@router.get("/", response_model=list[EventOut])
async def list_events(
    device_id: str | None = None,
    event_type: str | None = None,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = select(Event)
    if not is_admin(current_user):
        allowed_device_ids = await visible_device_ids(db, current_user)
        stmt = stmt.where(Event.device_id.in_(allowed_device_ids))

    if device_id is not None:
        stmt = stmt.where(Event.device_id == device_id)
    if event_type is not None:
        stmt = stmt.where(Event.event_type == event_type)

    stmt = stmt.order_by(Event.occurred_at.desc()).offset(offset).limit(limit)

    result = await db.execute(stmt)
    return result.scalars().all()
