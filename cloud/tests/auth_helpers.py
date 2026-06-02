from __future__ import annotations

from sqlalchemy import select


async def create_auth_user(
    db_session_factory,
    *,
    user_id: str,
    username: str,
    role: str,
    password: str,
    home_id: str | None,
    display_name: str | None = None,
    must_change_password: bool = False,
    is_active: bool = True,
) -> None:
    from cloud.app.auth import hash_password
    from cloud.app.models import Home, User

    async with db_session_factory() as session:
        if home_id is not None:
            home = (
                await session.execute(select(Home).where(Home.id == home_id))
            ).scalar_one_or_none()
            if home is None:
                session.add(Home(id=home_id, name=f"Home {home_id}"))
        session.add(
            User(
                id=user_id,
                username=username,
                display_name=display_name,
                role=role,
                password_hash=hash_password(password),
                home_id=home_id,
                must_change_password=must_change_password,
                is_active=is_active,
            )
        )
        await session.commit()


async def login_headers(client, username: str, password: str) -> dict[str, str]:
    response = await client.post(
        "/auth/login",
        json={"username": username, "password": password},
    )
    assert response.status_code == 200
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
