from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, field_serializer

TS_DISPLAY_FORMAT = "%H:%M %m/%d/%Y"


def _fmt_ts(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.strftime(TS_DISPLAY_FORMAT)


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

    @field_serializer("created_at", "updated_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


class DeviceStateOut(BaseModel):
    id: int
    device_id: str
    state: dict[str, Any]
    reported_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("reported_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


class CommandCreate(BaseModel):
    op: str
    target: dict[str, Any]
    timeout_ms: int | None = 5000


TERMINAL_STATUSES: frozenset[str] = frozenset({"executed", "failed", "timeout"})


class CommandOut(BaseModel):
    id: str
    device_id: str
    op: str
    target: dict[str, Any]
    status: str
    reason: str | None
    timeout_ms: int
    expires_at: datetime | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("expires_at", "created_at", "updated_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


class EventOut(BaseModel):
    id: int
    device_id: str | None
    event_type: str
    payload: dict[str, Any]
    occurred_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("occurred_at")
    def _ser_ts(self, v: datetime | None) -> str | None:
        return _fmt_ts(v)


class HealthOut(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"
