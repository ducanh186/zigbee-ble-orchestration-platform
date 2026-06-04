from __future__ import annotations

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from cloud.app.config import settings

# SQLAlchemy 2.0 async engine ------------------------------------------------
# Expects a postgresql+asyncpg:// URL from settings.
engine = create_async_engine(settings.database_url, echo=False)

async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


# Declarative base -----------------------------------------------------------
class Base(DeclarativeBase):
    pass


# FastAPI dependency ----------------------------------------------------------
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        yield session


# Table creation helper -------------------------------------------------------
async def ensure_automation_version_column(target_engine=None) -> None:
    """Idempotent backfill of the `automations.version` column on legacy DBs.

    SQLAlchemy ``Base.metadata.create_all()`` does not add columns to existing
    tables, so any DB created before Phase 1 of automation sync (which added
    ``Automation.version``) must be patched in place. This helper:

    - inspects the live schema first; if ``automations`` doesn't exist yet
      (fresh DB pre-``create_all``) it returns without action,
    - otherwise checks whether ``version`` is already present and, if not,
      runs a single ``ALTER TABLE`` (syntax valid on both SQLite and
      PostgreSQL).

    Running twice is a no-op because the inspector check short-circuits.
    """
    from sqlalchemy import inspect, text

    eng = target_engine if target_engine is not None else engine

    def _needs_column(sync_conn) -> bool:
        insp = inspect(sync_conn)
        if not insp.has_table("automations"):
            return False
        cols = {c["name"] for c in insp.get_columns("automations")}
        return "version" not in cols

    async with eng.begin() as conn:
        if await conn.run_sync(_needs_column):
            # Works for both SQLite and PostgreSQL.
            await conn.execute(
                text(
                    "ALTER TABLE automations "
                    "ADD COLUMN version INTEGER NOT NULL DEFAULT 1"
                )
            )


async def ensure_device_last_seen_column(target_engine=None) -> None:
    """Idempotent backfill of ``devices.last_seen_at`` on legacy DBs.

    Same shape as ``ensure_automation_version_column``: cross-dialect inspect
    + single ``ALTER TABLE`` if missing. Required because pre-2026-05-21 DBs
    don't have this column and the offline reaper queries it.
    """
    from sqlalchemy import inspect, text

    eng = target_engine if target_engine is not None else engine

    def _needs_column(sync_conn) -> bool:
        insp = inspect(sync_conn)
        if not insp.has_table("devices"):
            return False
        cols = {c["name"] for c in insp.get_columns("devices")}
        return "last_seen_at" not in cols

    async with eng.begin() as conn:
        if await conn.run_sync(_needs_column):
            await conn.execute(
                text("ALTER TABLE devices ADD COLUMN last_seen_at TIMESTAMP")
            )


async def ensure_user_auth_columns(target_engine=None) -> None:
    """Idempotent backfill for Phase A auth/RBAC columns on users."""
    from sqlalchemy import inspect, text

    eng = target_engine if target_engine is not None else engine

    def _missing_columns(sync_conn) -> set[str]:
        insp = inspect(sync_conn)
        if not insp.has_table("users"):
            return set()
        cols = {c["name"] for c in insp.get_columns("users")}
        return {
            "role",
            "password_hash",
            "display_name",
            "must_change_password",
            "is_active",
            "last_login_at",
            "password_changed_at",
            "updated_at",
        } - cols

    async with eng.begin() as conn:
        missing = await conn.run_sync(_missing_columns)
        if "role" in missing:
            await conn.execute(
                text(
                    "ALTER TABLE users "
                    "ADD COLUMN role VARCHAR NOT NULL DEFAULT 'viewer'"
                )
            )
        if "password_hash" in missing:
            await conn.execute(
                text("ALTER TABLE users ADD COLUMN password_hash VARCHAR")
            )
        if "display_name" in missing:
            await conn.execute(text("ALTER TABLE users ADD COLUMN display_name VARCHAR"))
        if "must_change_password" in missing:
            await conn.execute(
                text(
                    "ALTER TABLE users "
                    "ADD COLUMN must_change_password BOOLEAN NOT NULL DEFAULT false"
                )
            )
        if "is_active" in missing:
            await conn.execute(
                text("ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true")
            )
        if "last_login_at" in missing:
            await conn.execute(text("ALTER TABLE users ADD COLUMN last_login_at TIMESTAMP"))
        if "password_changed_at" in missing:
            await conn.execute(
                text("ALTER TABLE users ADD COLUMN password_changed_at TIMESTAMP")
            )
        if "updated_at" in missing:
            await conn.execute(text("ALTER TABLE users ADD COLUMN updated_at TIMESTAMP"))


async def normalize_user_roles(target_engine=None) -> None:
    """Idempotently migrate legacy public roles to canonical MVP roles."""
    from sqlalchemy import inspect, text

    eng = target_engine if target_engine is not None else engine

    def _has_role_column(sync_conn) -> bool:
        insp = inspect(sync_conn)
        if not insp.has_table("users"):
            return False
        cols = {c["name"] for c in insp.get_columns("users")}
        return "role" in cols

    async with eng.begin() as conn:
        if not await conn.run_sync(_has_role_column):
            return
        await conn.execute(
            text("UPDATE users SET role = 'parent' WHERE role IN ('operator', 'user')")
        )
        await conn.execute(
            text("UPDATE users SET role = 'viewer' WHERE role IN ('member', '')")
        )
        await conn.execute(
            text(
                "UPDATE users SET role = 'viewer' "
                "WHERE role IS NULL OR role NOT IN ('admin', 'parent', 'viewer')"
            )
        )


async def init_db() -> None:
    """Create missing tables and apply lightweight column migrations.

    `create_all` does not add columns to existing tables, so for evolving
    schemas we append idempotent ALTER TABLE statements.
    """
    from sqlalchemy import text

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        if engine.dialect.name == "postgresql":
            await conn.execute(
                text(
                    "ALTER TABLE commands "
                    "ADD COLUMN IF NOT EXISTS timeout_ms INTEGER NOT NULL DEFAULT 5000"
                )
            )
            await conn.execute(
                text(
                    "ALTER TABLE commands "
                    "ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP"
                )
            )
            await conn.execute(
                text(
                    "ALTER TABLE commands "
                    "ADD COLUMN IF NOT EXISTS target_kind VARCHAR "
                    "NOT NULL DEFAULT 'device'"
                )
            )
            await conn.execute(
                text("ALTER TABLE commands ALTER COLUMN device_id DROP NOT NULL")
            )

    # Cross-dialect column backfill — runs on every startup, idempotent.
    await ensure_automation_version_column()
    await ensure_device_last_seen_column()
    await ensure_user_auth_columns()
    await normalize_user_roles()
