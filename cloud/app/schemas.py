from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict


class DeviceOut(BaseModel):
    id: str
    device_type: str
    eui64: str | None
    room_id: str | None
    name: str | None
    is_online: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DeviceStateOut(BaseModel):
    id: int
    device_id: str
    state: dict[str, Any]
    reported_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CommandCreate(BaseModel):
    op: str
    target: dict[str, Any]
    timeout_ms: int | None = 5000


class CommandOut(BaseModel):
    id: str
    device_id: str
    op: str
    target: dict[str, Any]
    status: str
    reason: str | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class EventOut(BaseModel):
    id: int
    device_id: str | None
    event_type: str
    payload: dict[str, Any]
    occurred_at: datetime

    model_config = ConfigDict(from_attributes=True)


class HealthOut(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"
