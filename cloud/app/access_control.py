from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy import false, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.models import Automation, Device, ProvisioningSession, Room, User
from cloud.app.roles import is_admin_role, is_parent_or_admin_role


def is_admin(user: User) -> bool:
    return is_admin_role(user.role)


def is_parent_or_admin(user: User) -> bool:
    return is_parent_or_admin_role(user.role)


def visible_device_clause(user: User):
    if is_admin(user):
        return None
    if user.home_id is None:
        return false()
    return or_(Device.room_id.is_(None), Room.home_id == user.home_id)


async def ensure_device_visible(
    db: AsyncSession,
    device: Device,
    user: User,
) -> None:
    if is_admin(user):
        return
    if user.home_id is None:
        raise HTTPException(status_code=403, detail="Device outside user home")
    if device.room_id is None:
        return

    room = await db.get(Room, device.room_id)
    if room is None or room.home_id != user.home_id:
        raise HTTPException(status_code=403, detail="Device outside user home")


async def get_visible_device_or_404(
    db: AsyncSession,
    device_id: str,
    user: User,
) -> Device:
    device = await db.get(Device, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")
    await ensure_device_visible(db, device, user)
    return device


async def ensure_device_manageable(
    db: AsyncSession,
    device: Device,
    user: User,
) -> None:
    if is_admin(user):
        return
    if not is_parent_or_admin(user) or user.home_id is None:
        raise HTTPException(status_code=403, detail="Device outside user home")
    if device.room_id is None:
        raise HTTPException(status_code=403, detail="Device outside user home")

    room = await db.get(Room, device.room_id)
    if room is None or room.home_id != user.home_id:
        raise HTTPException(status_code=403, detail="Device outside user home")


async def get_manageable_device_or_404(
    db: AsyncSession,
    device_id: str,
    user: User,
) -> Device:
    device = await db.get(Device, device_id)
    if device is None:
        raise HTTPException(status_code=404, detail="Device not found")
    await ensure_device_manageable(db, device, user)
    return device


async def ensure_room_visible(
    db: AsyncSession,
    room: Room,
    user: User,
) -> None:
    if is_admin(user):
        return
    if user.home_id is None or room.home_id != user.home_id:
        raise HTTPException(status_code=403, detail="Room outside user home")


def automation_device_ids(trigger: dict, actions: list[dict]) -> set[str]:
    ids: set[str] = set()
    trigger_device = trigger.get("device_id")
    if isinstance(trigger_device, str) and trigger_device:
        ids.add(trigger_device)
    for action in actions:
        action_device = action.get("device_id")
        if isinstance(action_device, str) and action_device:
            ids.add(action_device)
    return ids


async def ensure_automation_visible(
    db: AsyncSession,
    rule: Automation,
    user: User,
) -> None:
    if is_admin(user):
        return
    ids = automation_device_ids(rule.trigger, rule.actions)
    if not ids:
        raise HTTPException(status_code=403, detail="Automation outside user home")

    for device_id in ids:
        device = await db.get(Device, device_id)
        if device is None:
            raise HTTPException(status_code=403, detail="Automation outside user home")
        await ensure_device_visible(db, device, user)


async def filter_visible_automations(
    db: AsyncSession,
    rules: list[Automation],
    user: User,
) -> list[Automation]:
    if is_admin(user):
        return rules
    visible: list[Automation] = []
    for rule in rules:
        try:
            await ensure_automation_visible(db, rule, user)
        except HTTPException:
            continue
        visible.append(rule)
    return visible


async def ensure_provisioning_session_visible(
    db: AsyncSession,
    session: ProvisioningSession,
    user: User,
) -> None:
    if is_admin(user):
        return
    room = await db.get(Room, session.room_id)
    if room is None or user.home_id is None or room.home_id != user.home_id:
        raise HTTPException(
            status_code=403,
            detail="Provisioning session outside user home",
        )


async def visible_device_ids(db: AsyncSession, user: User) -> set[str]:
    if is_admin(user):
        result = await db.execute(select(Device.id))
        return set(result.scalars().all())

    clause = visible_device_clause(user)
    stmt = select(Device.id).outerjoin(Room, Device.room_id == Room.id)
    if clause is not None:
        stmt = stmt.where(clause)
    result = await db.execute(stmt)
    return set(result.scalars().all())
