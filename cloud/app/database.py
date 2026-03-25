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
    """Create all tables that do not yet exist."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
