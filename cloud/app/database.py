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
async def init_db() -> None:
    """Create missing tables and apply lightweight column migrations.

    `create_all` does not add columns to existing tables, so for evolving
    schemas we append idempotent ALTER TABLE statements for Postgres.
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
