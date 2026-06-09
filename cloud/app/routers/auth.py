from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from cloud.app.auth import (
    create_access_token,
    create_refresh_token,
    get_current_user,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from cloud.app.config import settings
from cloud.app.database import get_db
from cloud.app.models import AuthRefreshToken, User
from cloud.app.roles import canonical_role
from cloud.app.schemas import (
    AuthChangePassword,
    AuthLogin,
    AuthLogout,
    AuthRefreshRequest,
    AuthSessionOut,
    AuthUserOut,
)

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


def _access_expires_at(now: datetime) -> datetime:
    return datetime.fromtimestamp(
        now.replace(tzinfo=UTC).timestamp() + settings.auth_token_ttl_seconds,
        UTC,
    )


def _refresh_expires_at(now: datetime) -> datetime:
    return now + timedelta(seconds=settings.auth_refresh_token_ttl_seconds)


def _utc_out(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC)


def _new_refresh_token(user: User, now: datetime) -> tuple[str, AuthRefreshToken]:
    raw_token = create_refresh_token()
    token_row = AuthRefreshToken(
        id=str(uuid4()),
        user_id=user.id,
        token_hash=hash_refresh_token(raw_token),
        issued_at=now,
        expires_at=_refresh_expires_at(now),
    )
    return raw_token, token_row


def _session_out(
    user: User,
    *,
    refresh_token: str,
    refresh_expires_at: datetime,
    now: datetime,
) -> AuthSessionOut:
    return AuthSessionOut(
        access_token=create_access_token(user),
        refresh_token=refresh_token,
        username=user.username,
        user_id=user.id,
        display_name=user.display_name,
        role=canonical_role(user.role),
        home_id=user.home_id,
        must_change_password=user.must_change_password,
        expires_at=_access_expires_at(now),
        refresh_expires_at=_utc_out(refresh_expires_at),
    )


def _invalid_refresh_token() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid refresh token",
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
    refresh_token, refresh_row = _new_refresh_token(user, now)
    db.add(refresh_row)
    await db.commit()

    return _session_out(
        user,
        refresh_token=refresh_token,
        refresh_expires_at=refresh_row.expires_at,
        now=now,
    )


@router.post("/refresh", response_model=AuthSessionOut)
async def refresh(body: AuthRefreshRequest, db: AsyncSession = Depends(get_db)):
    now = datetime.now(UTC).replace(tzinfo=None)
    token_hash = hash_refresh_token(body.refresh_token)
    result = await db.execute(
        select(AuthRefreshToken).where(AuthRefreshToken.token_hash == token_hash)
    )
    stored = result.scalar_one_or_none()
    if (
        stored is None
        or stored.revoked_at is not None
        or stored.expires_at <= now
    ):
        raise _invalid_refresh_token()

    user = await db.get(User, stored.user_id)
    if user is None or not user.is_active:
        stored.revoked_at = now
        stored.last_used_at = now
        await db.commit()
        raise _invalid_refresh_token()

    stored.revoked_at = now
    stored.last_used_at = now
    refresh_token, refresh_row = _new_refresh_token(user, now)
    db.add(refresh_row)
    await db.commit()

    return _session_out(
        user,
        refresh_token=refresh_token,
        refresh_expires_at=refresh_row.expires_at,
        now=now,
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
    now = datetime.now(UTC).replace(tzinfo=None)
    current_user.password_changed_at = now
    result = await db.execute(
        select(AuthRefreshToken).where(
            AuthRefreshToken.user_id == current_user.id,
            AuthRefreshToken.revoked_at.is_(None),
        )
    )
    for token_row in result.scalars():
        token_row.revoked_at = now
    await db.commit()
    return None


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    body: AuthLogout | None = None,
    db: AsyncSession = Depends(get_db),
):
    refresh_token = None if body is None else body.refresh_token
    if refresh_token:
        now = datetime.now(UTC).replace(tzinfo=None)
        result = await db.execute(
            select(AuthRefreshToken).where(
                AuthRefreshToken.token_hash == hash_refresh_token(refresh_token)
            )
        )
        stored = result.scalar_one_or_none()
        if stored is not None and stored.revoked_at is None:
            stored.revoked_at = now
            stored.last_used_at = now
            await db.commit()
    return None
