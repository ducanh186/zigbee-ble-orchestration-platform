from __future__ import annotations

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy import JSON as _JSON
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

# JSONB on Postgres, plain JSON on sqlite (tests)
JSON = _JSON().with_variant(JSONB(), "postgresql")

from cloud.app.database import Base


class Home(Base):
    __tablename__ = "homes"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    created_at = Column(DateTime, default=func.now())

    rooms = relationship("Room", back_populates="home")
    users = relationship("User", back_populates="home")


class Room(Base):
    __tablename__ = "rooms"

    id = Column(String, primary_key=True)
    home_id = Column(String, ForeignKey("homes.id"), nullable=False)
    name = Column(String, nullable=False)
    created_at = Column(DateTime, default=func.now())

    home = relationship("Home", back_populates="rooms")
    devices = relationship("Device", back_populates="room")


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True)
    username = Column(String, unique=True, nullable=False)
    display_name = Column(String, nullable=True)
    role = Column(String, nullable=False, default="viewer", server_default="viewer")
    password_hash = Column(String, nullable=True)
    must_change_password = Column(Boolean, nullable=False, default=False, server_default="0")
    is_active = Column(Boolean, nullable=False, default=True, server_default="1")
    last_login_at = Column(DateTime, nullable=True)
    password_changed_at = Column(DateTime, nullable=True)
    home_id = Column(String, ForeignKey("homes.id"), nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    home = relationship("Home", back_populates="users")
    refresh_tokens = relationship("AuthRefreshToken", back_populates="user")


class AuthRefreshToken(Base):
    __tablename__ = "auth_refresh_tokens"

    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    token_hash = Column(String, unique=True, nullable=False)
    issued_at = Column(DateTime, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    revoked_at = Column(DateTime, nullable=True)
    last_used_at = Column(DateTime, nullable=True)

    user = relationship("User", back_populates="refresh_tokens")

    __table_args__ = (
        Index("ix_auth_refresh_tokens_user_revoked", "user_id", "revoked_at"),
    )


class Device(Base):
    __tablename__ = "devices"

    id = Column(String, primary_key=True)  # logical device_id, e.g. "light-01"
    device_type = Column(String, nullable=False)
    sensor_kind = Column(Integer, nullable=True)
    eui64 = Column(String, nullable=True)
    room_id = Column(String, ForeignKey("rooms.id"), nullable=True)
    name = Column(String, nullable=True)
    # `is_online` is intentionally False by default now. Historically it
    # defaulted to True, which made seed/probe rows that never report look
    # ONLINE forever. Reality is derived from `last_seen_at`: an MQTT
    # reported/event/registry handler bumps the timestamp and sets
    # `is_online=True`; the offline reaper in `device_lifecycle` flips it
    # back to False once `last_seen_at` is older than
    # `settings.device_offline_after_seconds` (or stays False forever for
    # rows that never reported).
    is_online = Column(Boolean, default=False, nullable=False)
    last_seen_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    room = relationship("Room", back_populates="devices")
    states = relationship("DeviceState", back_populates="device")
    events = relationship("Event", back_populates="device")
    commands = relationship("Command", back_populates="device")


class DeviceState(Base):
    __tablename__ = "device_states"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(String, ForeignKey("devices.id"), nullable=False)
    state = Column(JSON, nullable=False)
    reported_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=func.now())

    device = relationship("Device", back_populates="states")

    __table_args__ = (
        Index("ix_device_states_device_reported", "device_id", "reported_at"),
    )


class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(String, ForeignKey("devices.id"), nullable=True)
    event_type = Column(String, nullable=False)
    payload = Column(JSON, nullable=False)
    occurred_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=func.now())

    device = relationship("Device", back_populates="events")

    __table_args__ = (
        Index("ix_events_device_occurred", "device_id", "occurred_at"),
    )


class Command(Base):
    __tablename__ = "commands"

    id = Column(String, primary_key=True)  # command_id uuid
    # device_id is nullable for gateway-targeted commands (commissioning, ...).
    # For target_kind="device" it must be set to an existing devices.id.
    device_id = Column(String, ForeignKey("devices.id"), nullable=True)
    target_kind = Column(
        String, nullable=False, default="device", server_default="device"
    )
    op = Column(String, nullable=False)
    target = Column(JSON, nullable=False)
    status = Column(String, nullable=False, default="accepted")
    reason = Column(String, nullable=True)
    timeout_ms = Column(Integer, nullable=False, default=5000)
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    device = relationship("Device", back_populates="commands")

    __table_args__ = (
        Index("ix_commands_device_created", "device_id", "created_at"),
    )


class Automation(Base):
    __tablename__ = "automations"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    enabled = Column(Boolean, nullable=False, default=True, server_default="true")
    tenant_id = Column(String, nullable=False)
    site_id = Column(String, nullable=False)
    gateway_id = Column(String, nullable=False)
    version = Column(Integer, nullable=False, default=1, server_default="1")
    trigger_type = Column(
        Enum("event", "schedule", name="automation_trigger_type"),
        nullable=False,
        default="event",
        server_default="event",
    )
    schedule_cron = Column(Text, nullable=True)
    trigger = Column("trigger", JSON, nullable=False, quote=True)
    actions = Column(JSON, nullable=False)
    # Monotonic version bumped on every cloud-side mutation. Gateway uses this
    # to reject stale retained desired messages on reconnect / replay. See
    # docs/AUTOMATION_MQTT_CONTRACT.md §7.
    version = Column(Integer, nullable=False, default=1, server_default="1")
    sync_status = Column(String, nullable=False, default="pending")
    last_run_status = Column(String, nullable=False, default="never_run")
    last_error = Column(String, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index(
            "ix_automations_gateway_created",
            "tenant_id",
            "site_id",
            "gateway_id",
            "created_at",
        ),
    )


class AutomationEvent(Base):
    """Audit row for automation lifecycle and execution events from gateway."""

    __tablename__ = "automation_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    automation_id = Column(String, ForeignKey("automations.id"), nullable=True)
    event_type = Column(String, nullable=False)
    status = Column(String, nullable=True)
    reason = Column(String, nullable=True)
    payload = Column(JSON, nullable=False)
    occurred_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=func.now())

    __table_args__ = (
        Index(
            "ix_automation_events_rule_occurred",
            "automation_id",
            "occurred_at",
        ),
    )


class FactoryDevice(Base):
    """Factory-provisioned device secret indexed by public EUI64."""

    __tablename__ = "factory_devices"

    eui64 = Column(String, primary_key=True)
    install_code = Column(String, nullable=False)
    device_type = Column(String, nullable=False)
    model = Column(String, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True, server_default="true")
    claimed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("ix_factory_devices_type_active", "device_type", "is_active"),
    )


class ProvisioningSession(Base):
    """Secure install-code join session tracked by the cloud API."""

    __tablename__ = "provisioning_sessions"

    id = Column(String, primary_key=True)
    gateway_id = Column(String, nullable=False)
    room_id = Column(String, ForeignKey("rooms.id"), nullable=False)
    eui64 = Column(String, nullable=False)
    install_code = Column(String, nullable=False)
    device_type = Column(String, nullable=False)
    model = Column(String, nullable=True)
    status = Column(String, nullable=False, default="pending", server_default="pending")
    reason = Column(String, nullable=True)
    command_id = Column(String, ForeignKey("commands.id"), nullable=True)
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("ix_provisioning_sessions_eui64_status", "eui64", "status"),
        Index(
            "ix_provisioning_sessions_gateway_created",
            "gateway_id",
            "created_at",
        ),
    )
