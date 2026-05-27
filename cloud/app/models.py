from __future__ import annotations

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
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
    home_id = Column(String, ForeignKey("homes.id"), nullable=True)
    created_at = Column(DateTime, default=func.now())

    home = relationship("Home", back_populates="users")


class Device(Base):
    __tablename__ = "devices"

    id = Column(String, primary_key=True)  # logical device_id, e.g. "light-01"
    device_type = Column(String, nullable=False)
    eui64 = Column(String, nullable=True)
    room_id = Column(String, ForeignKey("rooms.id"), nullable=True)
    name = Column(String, nullable=True)
    is_online = Column(Boolean, default=True)
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
    trigger = Column("trigger", JSON, nullable=False, quote=True)
    actions = Column(JSON, nullable=False)
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
