from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.auth import create_access_token, get_current_user, hash_password, verify_password
from cloud.app.config import settings
from cloud.app.database import get_db
from cloud.app.models import User
from cloud.app.roles import canonical_role
from cloud.app.schemas import AuthChangePassword, AuthLogin, AuthSessionOut, AuthUserOut

router = APIRouter(prefix="/auth", tags=["auth"])


def _user_out(user: User) -> AuthUserOut:
    return AuthUserOut(
        username=user.username,
        user_id=user.id,
        display_name=user.display_name,
        role=canonical_role(user.role),
        home_id=user.home_id,
        must_change_password=user.must_change_password,
    )


@router.post("/login", response_model=AuthSessionOut)
async def login(body: AuthLogin, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == body.username))
    user = result.scalar_one_or_none()
    if (
        user is None
        or not user.is_active
        or not verify_password(body.password, user.password_hash)
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    now = datetime.now(UTC).replace(tzinfo=None)
    user.last_login_at = now
    await db.commit()

    return AuthSessionOut(
        access_token=create_access_token(user),
        username=user.username,
        user_id=user.id,
        display_name=user.display_name,
        role=canonical_role(user.role),
        home_id=user.home_id,
        must_change_password=user.must_change_password,
        expires_at=datetime.fromtimestamp(
            now.replace(tzinfo=UTC).timestamp() + settings.auth_token_ttl_seconds,
            UTC,
        ),
    )


@router.get("/me", response_model=AuthUserOut)
async def me(current_user: User = Depends(get_current_user)):
    return _user_out(current_user)


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    body: AuthChangePassword,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(body.old_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    current_user.password_hash = hash_password(body.new_password)
    current_user.must_change_password = False
    current_user.password_changed_at = datetime.now(UTC).replace(tzinfo=None)
    await db.commit()
    return None


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout():
    return None
