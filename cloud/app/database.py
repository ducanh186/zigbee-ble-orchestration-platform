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
# aiosqlite requires the "sqlite+aiosqlite:///" scheme.
_raw_url = settings.database_url
if _raw_url.startswith("sqlite:///"):
    _async_url = _raw_url.replace("sqlite:///", "sqlite+aiosqlite:///", 1)
else:
    _async_url = _raw_url

engine = create_async_engine(_async_url, echo=False)

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
    """Create all tables that do not yet exist."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
