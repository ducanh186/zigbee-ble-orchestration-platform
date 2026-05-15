from __future__ import annotations

import pytest


async def _seed_automation_devices(db_session_factory) -> None:
    from cloud.app.models import Device, Home, Room

    async with db_session_factory() as session:
        session.add(Home(id="home-1", name="Test Home"))
        session.add(Room(id="room-1", home_id="home-1", name="Living"))
        session.add_all(
            [
                Device(
                    id="light-01",
                    device_type="light",
                    room_id="room-1",
                    name="Main Light",
                    is_online=True,
                ),
                Device(
                    id="light-02",
                    device_type="light",
                    room_id="room-1",
                    name="Side Light",
                    is_online=True,
                ),
                Device(
                    id="switch-01",
                    device_type="switch",
                    room_id="room-1",
                    name="Wall Switch",
                    is_online=True,
                ),
                Device(
                    id="motion-01",
                    device_type="motion",
                    room_id="room-1",
                    name="Motion Sensor",
                    is_online=True,
                ),
            ]
        )
        await session.commit()


def _motion_on_rule() -> dict:
    return {
        "name": "Motion turns on lab lights",
        "enabled": True,
        "trigger": {
            "device_id": "motion-01",
            "device_type": "motion",
            "event": "occupancy_changed",
            "state": {"occupancy": "occupied"},
        },
        "actions": [
            {"device_id": "light-01", "device_type": "light", "command": "on"},
            {"device_id": "light-02", "device_type": "light", "command": "on"},
        ],
    }


@pytest.mark.asyncio
async def test_create_automation_persists_pending_rule(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)

    response = await client.post("/api/automations", json=_motion_on_rule())

    assert response.status_code == 201
    data = response.json()
    assert data["id"]
    assert data["name"] == "Motion turns on lab lights"
    assert data["enabled"] is True
    assert data["trigger"]["device_id"] == "motion-01"
    assert [action["device_id"] for action in data["actions"]] == [
        "light-01",
        "light-02",
    ]
    assert data["sync_status"] == "pending"
    assert data["last_run_status"] == "never_run"
    assert data["last_error"] is None


@pytest.mark.asyncio
async def test_list_and_detail_automations(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)
    created = (await client.post("/api/automations", json=_motion_on_rule())).json()

    list_response = await client.get("/api/automations")
    detail_response = await client.get(f"/api/automations/{created['id']}")

    assert list_response.status_code == 200
    assert [item["id"] for item in list_response.json()] == [created["id"]]
    assert detail_response.status_code == 200
    assert detail_response.json()["id"] == created["id"]


@pytest.mark.asyncio
async def test_enable_disable_automation_marks_sync_pending(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)
    body = _motion_on_rule() | {"enabled": False}
    created = (await client.post("/api/automations", json=body)).json()

    enable_response = await client.post(f"/api/automations/{created['id']}/enable")
    disable_response = await client.post(f"/api/automations/{created['id']}/disable")

    assert enable_response.status_code == 200
    assert enable_response.json()["enabled"] is True
    assert enable_response.json()["sync_status"] == "pending"
    assert disable_response.status_code == 200
    assert disable_response.json()["enabled"] is False
    assert disable_response.json()["sync_status"] == "pending"


@pytest.mark.asyncio
async def test_create_switch_toggle_to_light_toggle_rule(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)

    response = await client.post(
        "/api/automations",
        json={
            "name": "Switch toggles lights",
            "enabled": True,
            "trigger": {
                "device_id": "switch-01",
                "device_type": "switch",
                "event": "switch_toggle",
            },
            "actions": [
                {"device_id": "light-01", "device_type": "light", "command": "toggle"}
            ],
        },
    )

    assert response.status_code == 201
    assert response.json()["actions"][0]["command"] == "toggle"


@pytest.mark.asyncio
async def test_rejects_unsupported_motion_action_template(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)
    body = _motion_on_rule()
    body["actions"] = [
        {"device_id": "light-01", "device_type": "light", "command": "off"}
    ]

    response = await client.post("/api/automations", json=body)

    assert response.status_code == 422
    assert "occupied" in response.json()["detail"]


@pytest.mark.asyncio
async def test_rejects_non_light_action_device(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)
    body = _motion_on_rule()
    body["actions"] = [
        {"device_id": "switch-01", "device_type": "switch", "command": "toggle"}
    ]

    response = await client.post("/api/automations", json=body)

    assert response.status_code == 422
    assert "light" in response.json()["detail"]


@pytest.mark.asyncio
async def test_get_unknown_automation_404(client):
    response = await client.get("/api/automations/missing")

    assert response.status_code == 404
