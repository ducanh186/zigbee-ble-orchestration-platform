from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.auth import create_access_token, verify_password
from cloud.app.config import settings
from cloud.app.database import get_db
from cloud.app.models import User
from cloud.app.schemas import AuthLogin, AuthSessionOut

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=AuthSessionOut)
async def login(body: AuthLogin, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == body.username))
    user = result.scalar_one_or_none()
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    return AuthSessionOut(
        access_token=create_access_token(user),
        user_id=user.id,
        role=user.role,
        home_id=user.home_id,
        expires_at=datetime.fromtimestamp(
            datetime.now(UTC).timestamp() + settings.auth_token_ttl_seconds,
            UTC,
        ),
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout():
    return None
