from __future__ import annotations

import pytest

from cloud.tests.auth_helpers import create_auth_user, login_headers


async def _parent_headers(client, db_session_factory) -> dict[str, str]:
    await create_auth_user(
        db_session_factory,
        user_id="parent-1",
        username="parent",
        role="parent",
        password="parent-pass",
        home_id="home-1",
    )
    return await login_headers(client, "parent", "parent-pass")


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


def _schedule_on_rule(cron: str = "0 7 * * 1-5") -> dict:
    return {
        "name": "Weekday 7am light",
        "enabled": True,
        "trigger_type": "schedule",
        "schedule_cron": cron,
        "trigger": {"type": "schedule"},
        "actions": [
            {
                "type": "device_command",
                "device_id": "light-01",
                "device_type": "light",
                "command": "on",
            }
        ],
    }


@pytest.mark.asyncio
async def test_create_schedule_rule_persists_cron(
    client, db_session_factory, fake_mqtt
):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)

    response = await client.post(
        "/api/automations",
        json=_schedule_on_rule(),
        headers=headers,
    )

    assert response.status_code == 201, response.text
    assert response.json()["trigger_type"] == "schedule"
    assert response.json()["schedule_cron"] == "0 7 * * 1-5"


@pytest.mark.asyncio
async def test_create_schedule_rule_rejects_bad_cron(
    client, db_session_factory, fake_mqtt
):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)

    response = await client.post(
        "/api/automations",
        json=_schedule_on_rule("bad cron"),
        headers=headers,
    )

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_automation_persists_pending_rule(
    client, db_session_factory, fake_mqtt
):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)

    response = await client.post(
        "/api/automations", json=_motion_on_rule(), headers=headers
    )

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
    assert data["version"] == 1
    assert data["sync_status"] == "pending"
    assert data["last_run_status"] == "never_run"
    assert data["last_error"] is None
    pub = _auto_pubs(fake_mqtt)[-1]
    assert pub["automation_id"] == data["id"]
    assert pub["op"] == "upsert"
    assert pub["version"] == 1


@pytest.mark.asyncio
async def test_list_and_detail_automations(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    created = (
        await client.post(
            "/api/automations", json=_motion_on_rule(), headers=headers
        )
    ).json()

    list_response = await client.get("/api/automations", headers=headers)
    detail_response = await client.get(
        f"/api/automations/{created['id']}", headers=headers
    )

    assert list_response.status_code == 200
    assert [item["id"] for item in list_response.json()] == [created["id"]]
    assert detail_response.status_code == 200
    assert detail_response.json()["id"] == created["id"]


@pytest.mark.asyncio
async def test_enable_disable_automation_marks_sync_pending(
    client, db_session_factory, fake_mqtt
):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    body = _motion_on_rule() | {"enabled": False}
    created = (
        await client.post("/api/automations", json=body, headers=headers)
    ).json()

    enable_response = await client.post(
        f"/api/automations/{created['id']}/enable", headers=headers
    )
    disable_response = await client.post(
        f"/api/automations/{created['id']}/disable", headers=headers
    )

    assert enable_response.status_code == 200
    assert enable_response.json()["enabled"] is True
    assert enable_response.json()["version"] == 2
    assert enable_response.json()["sync_status"] == "pending"
    assert disable_response.status_code == 200
    assert disable_response.json()["enabled"] is False
    assert disable_response.json()["version"] == 3
    assert disable_response.json()["sync_status"] == "pending"
    pub = _auto_pubs(fake_mqtt)[-1]
    assert pub["enabled"] is False
    assert pub["version"] == 3


@pytest.mark.asyncio
async def test_update_automation_bumps_version_and_rejects_stale_version(
    client, db_session_factory, fake_mqtt
):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    created = (
        await client.post(
            "/api/automations", json=_motion_on_rule(), headers=headers
        )
    ).json()

    update_body = {
        "name": "Motion turns lights off",
        "enabled": True,
        "version": created["version"],
        "trigger": {
            "device_id": "motion-01",
            "device_type": "motion",
            "event": "occupancy_changed",
            "state": {"occupancy": "unoccupied"},
        },
        "actions": [
            {"device_id": "light-01", "device_type": "light", "command": "off"},
            {"device_id": "light-02", "device_type": "light", "command": "off"},
        ],
    }

    update_response = await client.put(
        f"/api/automations/{created['id']}",
        json=update_body,
        headers=headers,
    )
    stale_response = await client.put(
        f"/api/automations/{created['id']}",
        json=update_body,
        headers=headers,
    )

    assert update_response.status_code == 200
    assert update_response.json()["version"] == 2
    assert update_response.json()["actions"][0]["command"] == "off"
    pub = _auto_pubs(fake_mqtt)[-1]
    assert pub["version"] == 2
    assert pub["trigger"]["state"] == {"occupancy": "unoccupied"}
    assert stale_response.status_code == 409


@pytest.mark.asyncio
async def test_delete_automation_publishes_tombstone_and_marks_pending(
    client, db_session_factory, fake_mqtt
):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    created = (
        await client.post(
            "/api/automations", json=_motion_on_rule(), headers=headers
        )
    ).json()

    delete_response = await client.delete(
        f"/api/automations/{created['id']}", headers=headers
    )
    detail_response = await client.get(
        f"/api/automations/{created['id']}", headers=headers
    )

    assert delete_response.status_code == 200
    deleted = delete_response.json()
    assert deleted["sync_status"] == "pending"
    assert deleted["version"] == 2
    assert detail_response.status_code == 200
    pub = _auto_pubs(fake_mqtt)[-1]
    assert pub["automation_id"] == created["id"]
    assert pub["op"] == "delete"
    assert pub["version"] == 2


@pytest.mark.asyncio
async def test_create_switch_toggle_to_light_toggle_rule(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)

    response = await client.post(
        "/api/automations",
        headers=headers,
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
    body = response.json()
    assert body["actions"][0]["command"] == "toggle"
    # Trigger persisted unchanged when client already sent canonical value.
    assert body["trigger"]["event"] == "switch_toggle"


@pytest.mark.asyncio
async def test_create_switch_rule_normalizes_legacy_toggle_event(
    client, db_session_factory, fake_mqtt
):
    """Legacy mobile clients still emit `event: "toggle"` for switch triggers.

    Gateway only accepts the canonical `switch_toggle` (see
    docs/AUTOMATION_MQTT_CONTRACT.md §4.3 and gateway
    automation_rule.c:isAllowedTriggerEvent). Cloud must normalize the
    legacy value before saving to DB and before publishing on MQTT so
    the rule does not get rejected with `unsupported_trigger`.
    """
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)

    response = await client.post(
        "/api/automations",
        headers=headers,
        json={
            "name": "Switch toggles lights",
            "enabled": True,
            "trigger": {
                "device_id": "switch-01",
                "device_type": "switch",
                "event": "toggle",  # legacy mobile wire value
            },
            "actions": [
                {"device_id": "light-01", "device_type": "light", "command": "toggle"}
            ],
        },
    )

    assert response.status_code == 201
    body = response.json()
    # API response, DB and MQTT publish must all carry the canonical value.
    assert body["trigger"]["event"] == "switch_toggle"

    pubs = _auto_pubs(fake_mqtt)
    assert len(pubs) == 1
    assert pubs[0]["trigger"]["event"] == "switch_toggle"


@pytest.mark.asyncio
async def test_create_switch_rule_rejects_unknown_event(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)

    response = await client.post(
        "/api/automations",
        headers=headers,
        json={
            "name": "Bogus switch rule",
            "enabled": True,
            "trigger": {
                "device_id": "switch-01",
                "device_type": "switch",
                "event": "long_press",
            },
            "actions": [
                {"device_id": "light-01", "device_type": "light", "command": "toggle"}
            ],
        },
    )

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_update_normalizes_legacy_toggle_event(
    client, db_session_factory, fake_mqtt
):
    """PUT update path must also normalize `toggle` → `switch_toggle`."""
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    created = (
        await client.post(
            "/api/automations",
            headers=headers,
            json={
                "name": "Switch rule",
                "enabled": True,
                "trigger": {
                    "device_id": "switch-01",
                    "device_type": "switch",
                    "event": "switch_toggle",
                },
                "actions": [
                    {
                        "device_id": "light-01",
                        "device_type": "light",
                        "command": "toggle",
                    }
                ],
            },
        )
    ).json()

    response = await client.put(
        f"/api/automations/{created['id']}",
        headers=headers,
        json={
            "trigger": {
                "device_id": "switch-01",
                "device_type": "switch",
                "event": "toggle",  # legacy
            },
        },
    )

    assert response.status_code == 200
    assert response.json()["trigger"]["event"] == "switch_toggle"
    pubs = _auto_pubs(fake_mqtt)
    assert pubs[-1]["trigger"]["event"] == "switch_toggle"


@pytest.mark.asyncio
async def test_accepts_manual_motion_action_choice(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    body = _motion_on_rule()
    body["actions"] = [
        {"device_id": "light-01", "device_type": "light", "command": "off"}
    ]

    response = await client.post("/api/automations", json=body, headers=headers)

    assert response.status_code == 201
    assert response.json()["actions"][0]["command"] == "off"


@pytest.mark.asyncio
async def test_accepts_manual_switch_light_action_choice(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)

    response = await client.post(
        "/api/automations",
        headers=headers,
        json={
            "name": "Switch turns on lights",
            "enabled": True,
            "trigger": {
                "device_id": "switch-01",
                "device_type": "switch",
                "event": "switch_toggle",
            },
            "actions": [
                {"device_id": "light-01", "device_type": "light", "command": "on"}
            ],
        },
    )

    assert response.status_code == 201
    assert response.json()["actions"][0]["command"] == "on"


@pytest.mark.asyncio
async def test_rejects_non_light_action_device(client, db_session_factory):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    body = _motion_on_rule()
    body["actions"] = [
        {"device_id": "switch-01", "device_type": "switch", "command": "toggle"}
    ]

    response = await client.post("/api/automations", json=body, headers=headers)

    assert response.status_code == 422
    assert "light" in response.json()["detail"]


@pytest.mark.asyncio
async def test_get_unknown_automation_404(client, db_session_factory):
    headers = await _parent_headers(client, db_session_factory)

    response = await client.get("/api/automations/missing", headers=headers)

    assert response.status_code == 404


def _auto_pubs(fake_mqtt) -> list[dict]:
    return [p for p in fake_mqtt.published if p.get("kind") == "automation_desired"]


@pytest.mark.asyncio
async def test_create_publishes_retained_desired_upsert(
    client, db_session_factory, fake_mqtt
):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)

    response = await client.post(
        "/api/automations", json=_motion_on_rule(), headers=headers
    )

    assert response.status_code == 201
    rule = response.json()
    assert rule["version"] == 1
    pubs = _auto_pubs(fake_mqtt)
    assert len(pubs) == 1
    pub = pubs[0]
    assert pub["automation_id"] == rule["id"]
    assert pub["op"] == "upsert"
    assert pub["version"] == 1
    assert pub["enabled"] is True
    assert pub["name"] == rule["name"]
    assert pub["trigger"]["device_id"] == "motion-01"
    assert [a["device_id"] for a in pub["actions"]] == ["light-01", "light-02"]


@pytest.mark.asyncio
async def test_enable_disable_publish_desired_with_bumped_version(
    client, db_session_factory, fake_mqtt
):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    body = _motion_on_rule() | {"enabled": False}
    created = (
        await client.post("/api/automations", json=body, headers=headers)
    ).json()

    await client.post(f"/api/automations/{created['id']}/enable", headers=headers)
    await client.post(f"/api/automations/{created['id']}/disable", headers=headers)

    pubs = _auto_pubs(fake_mqtt)
    # create + enable + disable = 3 publishes
    assert len(pubs) == 3
    assert pubs[0]["op"] == "upsert" and pubs[0]["version"] == 1
    assert pubs[0]["enabled"] is False  # created with enabled=False
    assert pubs[1]["op"] == "upsert" and pubs[1]["version"] == 2
    assert pubs[1]["enabled"] is True
    assert pubs[2]["op"] == "upsert" and pubs[2]["version"] == 3
    assert pubs[2]["enabled"] is False


@pytest.mark.asyncio
async def test_put_update_publishes_desired_with_bumped_version(
    client, db_session_factory, fake_mqtt
):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    created = (
        await client.post(
            "/api/automations", json=_motion_on_rule(), headers=headers
        )
    ).json()

    response = await client.put(
        f"/api/automations/{created['id']}",
        json={"name": "Renamed", "enabled": False},
        headers=headers,
    )

    assert response.status_code == 200
    updated = response.json()
    assert updated["name"] == "Renamed"
    assert updated["enabled"] is False
    assert updated["version"] == 2
    pubs = _auto_pubs(fake_mqtt)
    assert pubs[-1]["op"] == "upsert"
    assert pubs[-1]["version"] == 2
    assert pubs[-1]["name"] == "Renamed"
    assert pubs[-1]["enabled"] is False


@pytest.mark.asyncio
async def test_delete_publishes_retained_tombstone(
    client, db_session_factory, fake_mqtt
):
    await _seed_automation_devices(db_session_factory)
    headers = await _parent_headers(client, db_session_factory)
    created = (
        await client.post(
            "/api/automations", json=_motion_on_rule(), headers=headers
        )
    ).json()

    response = await client.delete(
        f"/api/automations/{created['id']}", headers=headers
    )

    assert response.status_code == 200
    deleted = response.json()
    # Row is still present, in pending state, with bumped version.
    assert deleted["sync_status"] == "pending"
    assert deleted["version"] == 2
    pubs = _auto_pubs(fake_mqtt)
    assert pubs[-1]["op"] == "delete"
    assert pubs[-1]["version"] == 2
    # Detail GET still finds the row (gateway has not acked yet).
    detail = await client.get(f"/api/automations/{created['id']}", headers=headers)
    assert detail.status_code == 200


@pytest.mark.asyncio
async def test_reported_synced_updates_db_sync_status(db_session_factory):
    """Direct handler test: fake gateway reported sync_status=synced updates DB."""
    from cloud.app.mqtt_client import MQTTService
    from cloud.app.models import Automation
    import asyncio

    await _seed_automation_devices(db_session_factory)
    auto_id = "auto_reported_sync"
    async with db_session_factory() as session:
        session.add(
            Automation(
                id=auto_id,
                name="reported synced rule",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                trigger={"device_id": "motion-01"},
                actions=[{"device_id": "light-01"}],
                version=1,
                sync_status="pending",
                last_run_status="never_run",
                last_error=None,
            )
        )
        await session.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    service._handle_automation_reported(
        f"sb/v1/hust/lab01/gw-ubuntu-01/automations/{auto_id}/reported",
        {
            "schema": "sb.v1",
            "ts": 1779000000050,
            "payload": {
                "automation_id": auto_id,
                "version": 1,
                "sync_status": "synced",
                "last_error": None,
            },
        },
    )
    await tasks[0]
    async with db_session_factory() as session:
        rule = await session.get(Automation, auto_id)
        assert rule.sync_status == "synced"
        assert rule.last_error is None


@pytest.mark.asyncio
async def test_reported_failed_updates_last_error(db_session_factory):
    from cloud.app.mqtt_client import MQTTService
    from cloud.app.models import Automation
    import asyncio

    auto_id = "auto_reported_fail"
    async with db_session_factory() as session:
        session.add(
            Automation(
                id=auto_id,
                name="reported failed rule",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                trigger={},
                actions=[{}],
                version=2,
                sync_status="pending",
                last_run_status="never_run",
                last_error=None,
            )
        )
        await session.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    service._handle_automation_reported(
        f"sb/v1/hust/lab01/gw-ubuntu-01/automations/{auto_id}/reported",
        {
            "payload": {
                "automation_id": auto_id,
                "version": 2,
                "sync_status": "failed",
                "last_error": "rule_table_full",
            },
        },
    )
    await tasks[0]
    async with db_session_factory() as session:
        rule = await session.get(Automation, auto_id)
        assert rule.sync_status == "failed"
        assert rule.last_error == "rule_table_full"


@pytest.mark.asyncio
async def test_reported_deleted_hard_deletes_row(db_session_factory):
    from cloud.app.mqtt_client import MQTTService
    from cloud.app.models import Automation
    import asyncio

    auto_id = "auto_reported_del"
    async with db_session_factory() as session:
        session.add(
            Automation(
                id=auto_id,
                name="to be deleted",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                trigger={},
                actions=[{}],
                version=3,
                sync_status="pending",
                last_run_status="never_run",
                last_error=None,
            )
        )
        await session.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    service._handle_automation_reported(
        f"sb/v1/hust/lab01/gw-ubuntu-01/automations/{auto_id}/reported",
        {
            "payload": {
                "automation_id": auto_id,
                "version": 3,
                "sync_status": "deleted",
                "last_error": None,
            },
        },
    )
    await tasks[0]
    async with db_session_factory() as session:
        assert await session.get(Automation, auto_id) is None


@pytest.mark.asyncio
async def test_automation_event_inserts_event_and_updates_last_run(
    db_session_factory,
):
    from cloud.app.mqtt_client import MQTTService
    from cloud.app.models import Automation, Event
    from sqlalchemy import select
    import asyncio

    auto_id = "auto_event_test"
    async with db_session_factory() as session:
        session.add(
            Automation(
                id=auto_id,
                name="fired rule",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                trigger={},
                actions=[{}],
                version=1,
                sync_status="synced",
                last_run_status="never_run",
                last_error=None,
            )
        )
        await session.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    service._handle_automation_event(
        f"sb/v1/hust/lab01/gw-ubuntu-01/automations/{auto_id}/event",
        {
            "ts": 1779000123456,
            "payload": {
                "automation_id": auto_id,
                "event": "rule_fired",
                "run_id": "run_test_01",
                "version": 1,
                "trigger": {"device_id": "switch-01", "event": "switch_toggle"},
                "actions": [
                    {
                        "device_id": "light-01",
                        "command": "toggle",
                        "status": "executed",
                        "reason": None,
                        "command_id": None,
                    }
                ],
                "status": "executed",
                "last_error": None,
            },
        },
    )
    await tasks[0]
    async with db_session_factory() as session:
        rule = await session.get(Automation, auto_id)
        assert rule.last_run_status == "executed"
        assert rule.last_error is None
        events = (
            await session.execute(
                select(Event).where(Event.event_type == "automation_rule_fired")
            )
        ).scalars().all()
        assert len(events) == 1
        assert events[0].payload["run_id"] == "run_test_01"


@pytest.mark.asyncio
async def test_reported_invalid_sync_status_is_ignored(db_session_factory):
    """Garbled `sync_status` from gateway must not corrupt the row."""
    from cloud.app.mqtt_client import MQTTService
    from cloud.app.models import Automation
    import asyncio

    auto_id = "auto_bad_status"
    async with db_session_factory() as session:
        session.add(
            Automation(
                id=auto_id,
                name="bad-status rule",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                trigger={},
                actions=[{}],
                version=1,
                sync_status="pending",
                last_run_status="never_run",
                last_error=None,
            )
        )
        await session.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    service._handle_automation_reported(
        f"sb/v1/hust/lab01/gw-ubuntu-01/automations/{auto_id}/reported",
        {
            "payload": {
                "automation_id": auto_id,
                "version": 1,
                "sync_status": "garbage",
                "last_error": None,
            }
        },
    )
    # Handler short-circuits before scheduling write; tasks list empty.
    assert tasks == []
    async with db_session_factory() as session:
        rule = await session.get(Automation, auto_id)
        assert rule.sync_status == "pending"


@pytest.mark.asyncio
async def test_reported_unknown_id_is_logged_safely(db_session_factory):
    """Reported for an unknown automation_id must not crash; just log + skip."""
    from cloud.app.mqtt_client import MQTTService
    import asyncio

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    service._handle_automation_reported(
        "sb/v1/hust/lab01/gw-ubuntu-01/automations/auto_ghost/reported",
        {
            "payload": {
                "automation_id": "auto_ghost",
                "version": 1,
                "sync_status": "synced",
            }
        },
    )
    # The handler schedules a write but the write returns early when row is
    # missing — there is nothing to assert beyond "didn't crash".
    if tasks:
        await tasks[0]


@pytest.mark.asyncio
async def test_event_non_terminal_status_does_not_touch_last_run(db_session_factory):
    """`skipped` is not terminal — last_run_status / last_error must stay put."""
    from cloud.app.mqtt_client import MQTTService
    from cloud.app.models import Automation
    import asyncio

    auto_id = "auto_event_skip"
    async with db_session_factory() as session:
        session.add(
            Automation(
                id=auto_id,
                name="skipped rule",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                trigger={},
                actions=[{}],
                version=1,
                sync_status="synced",
                last_run_status="executed",   # set by a prior fire
                last_error="prev-error",
            )
        )
        await session.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    service._handle_automation_event(
        f"sb/v1/hust/lab01/gw-ubuntu-01/automations/{auto_id}/event",
        {
            "ts": 1779000999999,
            "payload": {
                "automation_id": auto_id,
                "event": "rule_skipped",
                "status": "skipped",
                "run_id": "run_skip_01",
                "version": 1,
            },
        },
    )
    await tasks[0]
    async with db_session_factory() as session:
        rule = await session.get(Automation, auto_id)
        # Non-terminal status -- last_run_status and last_error unchanged.
        assert rule.last_run_status == "executed"
        assert rule.last_error == "prev-error"


@pytest.mark.asyncio
async def test_ensure_automation_version_column_fresh_db_noop(db_session_factory):
    """Fresh DB already has the column; migration is a no-op."""
    import cloud.app.database as dbmod
    from cloud.app.database import ensure_automation_version_column
    from sqlalchemy import inspect

    eng = dbmod.engine  # monkey-patched by db_session_factory fixture

    async with eng.begin() as conn:
        cols = await conn.run_sync(
            lambda sc: {c["name"] for c in inspect(sc).get_columns("automations")}
        )
        assert "version" in cols

    # Running twice must be safe.
    await ensure_automation_version_column(target_engine=eng)
    await ensure_automation_version_column(target_engine=eng)


@pytest.mark.asyncio
async def test_ensure_automation_version_column_upgrades_legacy_sqlite(tmp_path):
    """Old DB (created before Phase 1) gets the column added without data loss."""
    from sqlalchemy import inspect, text
    from sqlalchemy.ext.asyncio import create_async_engine
    from cloud.app.database import ensure_automation_version_column

    db_path = tmp_path / "legacy.db"
    eng = create_async_engine(f"sqlite+aiosqlite:///{db_path}", echo=False)
    try:
        # Build the pre-Phase-1 schema (no `version` column) and seed a row.
        async with eng.begin() as conn:
            await conn.execute(text(
                "CREATE TABLE automations ("
                " id VARCHAR PRIMARY KEY,"
                " name VARCHAR NOT NULL,"
                " enabled BOOLEAN NOT NULL DEFAULT 1,"
                " tenant_id VARCHAR NOT NULL,"
                " site_id VARCHAR NOT NULL,"
                " gateway_id VARCHAR NOT NULL,"
                " \"trigger\" TEXT NOT NULL,"
                " actions TEXT NOT NULL,"
                " sync_status VARCHAR NOT NULL DEFAULT 'pending',"
                " last_run_status VARCHAR NOT NULL DEFAULT 'never_run',"
                " last_error VARCHAR,"
                " created_at TIMESTAMP,"
                " updated_at TIMESTAMP"
                ")"
            ))
            await conn.execute(text(
                "INSERT INTO automations(id,name,enabled,tenant_id,site_id,"
                " gateway_id,\"trigger\",actions) "
                "VALUES('legacy-1','old',1,'hust','lab01','gw-ubuntu-01','{}','[]')"
            ))

        async with eng.begin() as conn:
            cols_before = await conn.run_sync(
                lambda sc: {c["name"] for c in inspect(sc).get_columns("automations")}
            )
            assert "version" not in cols_before

        # Run migration twice to exercise idempotence.
        await ensure_automation_version_column(target_engine=eng)
        await ensure_automation_version_column(target_engine=eng)

        async with eng.begin() as conn:
            cols_after = await conn.run_sync(
                lambda sc: {c["name"] for c in inspect(sc).get_columns("automations")}
            )
            assert "version" in cols_after
            # Existing row gets the column default.
            row = (await conn.execute(text(
                "SELECT id, version FROM automations WHERE id='legacy-1'"
            ))).first()
            assert row is not None
            assert row[1] == 1
    finally:
        await eng.dispose()


@pytest.mark.asyncio
async def test_reported_stale_version_ignored(db_session_factory):
    from cloud.app.mqtt_client import MQTTService
    from cloud.app.models import Automation
    import asyncio

    auto_id = "auto_stale"
    async with db_session_factory() as session:
        session.add(
            Automation(
                id=auto_id,
                name="stale ack",
                enabled=True,
                tenant_id="hust",
                site_id="lab01",
                gateway_id="gw-ubuntu-01",
                trigger={},
                actions=[{}],
                version=5,
                sync_status="pending",
                last_run_status="never_run",
                last_error=None,
            )
        )
        await session.commit()

    service = MQTTService()
    service.set_db_session_factory(db_session_factory)
    tasks: list[asyncio.Task] = []
    service._run_async = lambda c: tasks.append(asyncio.create_task(c()))

    service._handle_automation_reported(
        f"sb/v1/hust/lab01/gw-ubuntu-01/automations/{auto_id}/reported",
        {"payload": {"automation_id": auto_id, "version": 2, "sync_status": "synced"}},
    )
    await tasks[0]
    async with db_session_factory() as session:
        rule = await session.get(Automation, auto_id)
        # Still pending — ack was stale, ignored.
        assert rule.sync_status == "pending"
