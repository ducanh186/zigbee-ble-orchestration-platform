from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.access_control import (
    get_visible_device_or_404,
    is_parent_or_admin,
)
from cloud.app.auth import get_current_user, require_parent_or_admin
from cloud.app.command_execution import (
    CommandExecutionError,
    execute_device_command,
)
from cloud.app.database import get_db
from cloud.app.models import Command, User
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
    current_user: User = Depends(require_parent_or_admin),
):
    try:
        return await execute_device_command(
            db,
            device_id=device_id,
            op=body.op,
            target=body.target,
            timeout_ms=body.timeout_ms or 5000,
            current_user=current_user,
        )
    except CommandExecutionError as exc:
        raise HTTPException(
            status_code=exc.status_code,
            detail=exc.detail,
        ) from exc


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
        if not is_parent_or_admin(current_user):
            raise HTTPException(status_code=403, detail="Command outside user home")
    else:
        await get_visible_device_or_404(db, cmd.device_id, current_user)
    return cmd
