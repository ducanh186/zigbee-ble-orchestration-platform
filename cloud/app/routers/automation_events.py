from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import ensure_automation_visible
from cloud.app.auth import get_current_user
from cloud.app.database import get_db
from cloud.app.models import Automation, AutomationEvent, User
from cloud.app.schemas import AutomationEventOut

router = APIRouter(prefix="/api/automation-events", tags=["automation-events"])


@router.get("", response_model=list[AutomationEventOut])
async def list_automation_events(
    automation_id: str | None = None,
    event_type: str | None = None,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = select(AutomationEvent)

    if automation_id is not None:
        stmt = stmt.where(AutomationEvent.automation_id == automation_id)
    if event_type is not None:
        stmt = stmt.where(AutomationEvent.event_type == event_type)

    stmt = stmt.order_by(AutomationEvent.occurred_at.desc())
    result = await db.execute(stmt)
    events = result.scalars().all()

    if current_user.role == "admin":
        return events[offset : offset + limit]

    visible = []
    for event in events:
        if event.automation_id is None:
            continue
        rule = await db.get(Automation, event.automation_id)
        if rule is None:
            continue
        try:
            await ensure_automation_visible(db, rule, current_user)
        except HTTPException:
            continue
        visible.append(event)
    return visible[offset : offset + limit]
