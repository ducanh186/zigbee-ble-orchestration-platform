"""
Pydantic models for MQTT envelopes, IPC records, and OTA payloads.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any, Literal
from uuid import uuid4

from pydantic import AnyUrl, BaseModel, ConfigDict, Field, field_validator


COMMAND_STATUSES = ("accepted", "queued", "sent", "executed", "failed", "timeout")
IPC_KINDS = (
    "registry",
    "reported",
    "event",
    "gateway_health",
    "gateway_log",
    "command_reply",
    "ota_progress",
    "ota_event",
    "desired",
    "command_request",
    "ota_manifest",
    "ota_desired",
)


def utc_now() -> datetime:
    """Return a UTC timestamp rounded to whole seconds."""

    return datetime.now(UTC).replace(microsecond=0)


def new_message_id() -> str:
    """Return a compact opaque message identifier."""

    return uuid4().hex


class MQTTEnvelope(BaseModel):
    """Common MQTT envelope for every broker message."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    schema_name: Literal["sb.v1"] = Field(
        default="sb.v1",
        alias="schema",
        serialization_alias="schema",
    )
    msg_id: str = Field(default_factory=new_message_id)
    ts: datetime = Field(default_factory=utc_now)
    tenant_id: str
    site_id: str
    gateway_id: str
    source: str
    trace_id: str | None = None
    correlation_id: str | None = None
    payload: dict[str, Any]

    @field_validator("msg_id", "tenant_id", "site_id", "gateway_id", "source")
    @classmethod
    def validate_non_empty_string(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("Field must not be empty")
        return value.strip()


class GatewayOnlinePayload(BaseModel):
    """Payload for gateway/online."""

    model_config = ConfigDict(extra="forbid")
    value: Literal["online", "offline"]


class CommandRequestPayload(BaseModel):
    """Payload for commands/{command_id}/request."""

    model_config = ConfigDict(extra="allow")

    device_id: str
    op: str
    target: dict[str, Any]
    timeout_ms: int | None = None

    @field_validator("device_id", "op")
    @classmethod
    def validate_required_strings(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("Field must not be empty")
        return value.strip()


class CommandReplyPayload(BaseModel):
    """Normalized payload for commands/{command_id}/reply."""

    model_config = ConfigDict(extra="allow")

    status: Literal["accepted", "queued", "sent", "executed", "failed", "timeout"]
    device_id: str | None = None
    reason: str | None = None


class OTAArtifactPayload(BaseModel):
    """Artifact details embedded in OTA campaign manifests."""

    model_config = ConfigDict(extra="allow")

    url: AnyUrl
    sha256: str
    size_bytes: int
    file_version: int | None = None
    stack_version: str | None = None

    @field_validator("sha256")
    @classmethod
    def validate_sha256(cls, value: str) -> str:
        normalized = value.lower()
        if len(normalized) != 64 or any(ch not in "0123456789abcdef" for ch in normalized):
            raise ValueError("artifact.sha256 must be a 64-character lowercase hex string")
        return normalized

    @field_validator("size_bytes")
    @classmethod
    def validate_size_bytes(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("artifact.size_bytes must be positive")
        return value


class OTACampaignManifestPayload(BaseModel):
    """Payload for ota/campaigns/{campaign_id}/manifest."""

    model_config = ConfigDict(extra="allow")

    campaign_id: str
    target: dict[str, Any]
    artifact: OTAArtifactPayload
    rollout: dict[str, Any] | None = None
    policy: dict[str, Any] | None = None

    @field_validator("campaign_id")
    @classmethod
    def validate_campaign_id(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("campaign_id must not be empty")
        return value.strip()


class OTADeviceDesiredPayload(BaseModel):
    """Payload for ota/devices/{device_id}/desired."""

    model_config = ConfigDict(extra="allow")

    campaign_id: str
    action: str

    @field_validator("campaign_id", "action")
    @classmethod
    def validate_non_empty_string(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("Field must not be empty")
        return value.strip()


class IPCRecord(BaseModel):
    """Common NDJSON record sent over the local IPC socket."""

    model_config = ConfigDict(extra="forbid")

    v: Literal[1] = 1
    kind: str
    msg_id: str = Field(default_factory=new_message_id)
    ts: datetime = Field(default_factory=utc_now)
    source: str
    trace_id: str | None = None
    correlation_id: str | None = None
    device_id: str | None = None
    command_id: str | None = None
    campaign_id: str | None = None
    status: str | None = None
    payload: dict[str, Any] = Field(default_factory=dict)

    @field_validator("kind")
    @classmethod
    def validate_kind(cls, value: str) -> str:
        if value not in IPC_KINDS:
            raise ValueError(f"Unsupported IPC kind: {value}")
        return value

    @field_validator("source")
    @classmethod
    def validate_source(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("source must not be empty")
        return value.strip()

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str | None) -> str | None:
        if value is None:
            return value
        if value not in COMMAND_STATUSES:
            raise ValueError(f"Unsupported command status: {value}")
        return value
