from __future__ import annotations

import pytest

from cloud.app.provisioning_install_code import validate_install_code


VALID_EUI64 = "A8D417FEFF570B00"
VALID_INSTALL_CODE = "83FED3407A939723A5C639B26916D505C3B5"


@pytest.mark.asyncio
async def test_label_api_generates_contract_payload_and_svg(client):
    response = await client.post(
        "/api/provisioning/labels",
        json={
            "eui64": VALID_EUI64,
            "device_type": "light",
            "model": "EFR32MG12_LIGHT_KIT",
        },
    )

    assert response.status_code == 201
    data = response.json()
    payload = data["payload"]
    assert payload["version"] == 1
    assert payload["eui64"] == VALID_EUI64
    assert payload["device_type"] == "light"
    assert payload["model"] == "EFR32MG12_LIGHT_KIT"
    assert validate_install_code(payload["install_code"])
    assert data["payload_json"].startswith('{"version":1,')
    assert data["qr_svg"].lstrip().startswith("<?xml")
    assert "<svg" in data["qr_svg"]
    assert payload["install_code"] not in data["qr_svg"]


@pytest.mark.asyncio
async def test_label_api_accepts_valid_existing_install_code(client):
    response = await client.post(
        "/api/provisioning/labels",
        json={
            "eui64": VALID_EUI64,
            "install_code": VALID_INSTALL_CODE,
            "device_type": "switch",
        },
    )

    assert response.status_code == 201
    assert response.json()["payload"]["install_code"] == VALID_INSTALL_CODE


@pytest.mark.asyncio
async def test_label_api_rejects_wrong_install_code_crc(client):
    response = await client.post(
        "/api/provisioning/labels",
        json={
            "eui64": VALID_EUI64,
            "install_code": VALID_INSTALL_CODE[:-4] + "0000",
            "device_type": "motion",
        },
    )

    assert response.status_code == 422
