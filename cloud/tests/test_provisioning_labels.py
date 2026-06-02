from __future__ import annotations

import pytest


VALID_EUI64 = "A8D417FEFF570B00"
VALID_INSTALL_CODE = "83FED3407A939723A5C639B26916D505C3B5"


async def _admin_headers(client, db_session_factory) -> dict[str, str]:
    from cloud.app.auth import hash_password
    from cloud.app.models import User

    async with db_session_factory() as session:
        session.add(
            User(
                id="admin-1",
                username="admin",
                role="admin",
                password_hash=hash_password("admin-pass"),
            )
        )
        await session.commit()

    login = await client.post(
        "/auth/login",
        json={"username": "admin", "password": "admin-pass"},
    )
    assert login.status_code == 200
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


@pytest.mark.asyncio
async def test_label_api_generates_contract_payload_and_svg(client, db_session_factory):
    headers = await _admin_headers(client, db_session_factory)
    response = await client.post(
        "/api/provisioning/labels",
        json={
            "eui64": VALID_EUI64,
            "device_type": "light",
            "model": "EFR32MG12_LIGHT_KIT",
        },
        headers=headers,
    )

    assert response.status_code == 201
    data = response.json()
    payload = data["payload"]
    assert payload == {
        "version": 1,
        "eui64": VALID_EUI64,
        "device_type": "light",
    }
    assert data["payload_json"] == (
        '{"version":1,"eui64":"A8D417FEFF570B00","device_type":"light"}'
    )
    assert data["qr_svg"].lstrip().startswith("<?xml")
    assert "<svg" in data["qr_svg"]
    assert "install_code" not in data["payload_json"]
    assert "install_code" not in data["qr_svg"]
    assert VALID_INSTALL_CODE not in data["payload_json"]
    assert VALID_INSTALL_CODE not in data["qr_svg"]
