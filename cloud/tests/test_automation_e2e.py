"""SCRUM-51 — Automation end-to-end test suite.

Covers the cloud-side acceptance matrix described in
`docs/automation-e2e-plan.md` (rows C1..C8 and E6).  Gateway / hardware
harness rows (G1..G7, E1..E5) are exercised by the gateway test runner
under `gateway/Z3GatewayHost/` and via manual demo evidence — see
`docs/automation-e2e-report-20260521.md`.
"""
from __future__ import annotations

import asyncio
from datetime import datetime

import pytest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _seed_devices(db_session_factory) -> None:
    from cloud.app.models import Device, Home, Room

    async with db_session_factory() as session:
        session.add(Home(id="home-1", name="Test Home"))
        session.add(Room(id="room-1", home_id="home-1", name="Living"))
        session.add_all(
            [
                Device(
                    id="motion-01",
                    device_type="motion",
                    room_id="room-1",
                    name="Motion Sensor",
                    is_online=True,
                ),
                Device(
                    id="light-01",
                    device_type="light",
                    room_id="room-1",
                    name="Main Light",
                    is_online=True,
                ),
                Device(
                    id="switch-01",
                    device_type="switch",
                    room_id="room-1",
                    name="Wall Switch",
                    is_online=True,
                ),
            ]
        )
        await session.commit()


def _motion_rule() -> dict:
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
        ],
    }


# ---------------------------------------------------------------------------
# Cloud API matrix (C1..C8)
# ---------------------------------------------------------------------------


class TestAutomationCloudApi:
    @pytest.mark.asyncio
    async def test_c1_create_rule_returns_201_and_version_1(
        self, client, db_session_factory
    ):
        await _seed_devices(db_session_factory)
        resp = await client.post("/api/automations", json=_motion_rule())
        assert resp.status_code == 201
        body = resp.json()
        assert body["version"] == 1
        assert body["sync_status"] == "pending"
        assert body["last_run_status"] == "never_run"

    @pytest.mark.asyncio
    async def test_c2_update_rule_bumps_version(self, client, db_session_factory):
        await _seed_devices(db_session_factory)
        created = (
            await client.post("/api/automations", json=_motion_rule())
        ).json()

        update = _motion_rule() | {"version": 1, "name": "Renamed"}
        resp = await client.put(
            f"/api/automations/{created['id']}", json=update
        )

        assert resp.status_code == 200
        assert resp.json()["version"] == 2
        assert resp.json()["name"] == "Renamed"

    @pytest.mark.asyncio
    async def test_c3_delete_rule_returns_204_and_removes_it(
        self, client, db_session_factory
    ):
        await _seed_devices(db_session_factory)
        created = (
            await client.post("/api/automations", json=_motion_rule())
        ).json()

        del_resp = await client.delete(f"/api/automations/{created['id']}")
        get_resp = await client.get(f"/api/automations/{created['id']}")

        assert del_resp.status_code == 204
        assert get_resp.status_code == 404

    @pytest.mark.asyncio
    async def test_c4_create_rule_rejects_missing_trigger(
        self, client, db_session_factory
    ):
        await _seed_devices(db_session_factory)
        body = _motion_rule()
        body.pop("trigger")

        resp = await client.post("/api/automations", json=body)

        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_c5_create_rule_rejects_unknown_action_type(
        self, client, db_session_factory
    ):
        await _seed_devices(db_session_factory)
        body = _motion_rule()
        body["actions"] = [
            {
                "device_id": "switch-01",
                "device_type": "switch",
                "command": "toggle",
            }
        ]

        resp = await client.post("/api/automations", json=body)

        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_c6_create_rule_publishes_desired_automation_message(
        self, client, db_session_factory, fake_mqtt
    ):
        await _seed_devices(db_session_factory)
        created = (
            await client.post("/api/automations", json=_motion_rule())
        ).json()

        published = fake_mqtt.published[-1]
        assert published["topic"].endswith(
            f"/desired/automation/{created['id']}"
        )
        assert published["retain"] is True
        assert published["payload"]["payload"]["deleted"] is False

    @pytest.mark.asyncio
    async def test_c7_delete_rule_publishes_tombstone(
        self, client, db_session_factory, fake_mqtt
    ):
        await _seed_devices(db_session_factory)
        created = (
            await client.post("/api/automations", json=_motion_rule())
        ).json()

        await client.delete(f"/api/automations/{created['id']}")

        last = fake_mqtt.published[-1]
        assert last["topic"].endswith(
            f"/desired/automation/{created['id']}"
        )
        assert last["payload"]["payload"]["deleted"] is True
        assert last["payload"]["payload"]["version"] == 2

    @pytest.mark.asyncio
    async def test_c8_concurrent_update_obeys_version_contract(
        self, client, db_session_factory
    ):
        await _seed_devices(db_session_factory)
        created = (
            await client.post("/api/automations", json=_motion_rule())
        ).json()

        ok_update = _motion_rule() | {"version": 1, "name": "First"}
        stale_update = _motion_rule() | {"version": 1, "name": "Second"}

        first = await client.put(
            f"/api/automations/{created['id']}", json=ok_update
        )
        second = await client.put(
            f"/api/automations/{created['id']}", json=stale_update
        )

        assert first.status_code == 200
        assert second.status_code == 409


# ---------------------------------------------------------------------------
# Composed end-to-end (E6 — cloud event log)
# ---------------------------------------------------------------------------


class TestAutomationComposeE2E:
    @pytest.mark.asyncio
    async def test_e6_cloud_event_log_returns_execution_rows(
        self, client, db_session_factory
    ):
        from cloud.app.mqtt_client import MQTTService

        await _seed_devices(db_session_factory)
        created = (
            await client.post("/api/automations", json=_motion_rule())
        ).json()

        service = MQTTService()
        service.set_db_session_factory(db_session_factory)
        service._loop = asyncio.get_running_loop()
        tasks: list[asyncio.Task] = []
        service._run_async = lambda coro_func: tasks.append(  # type: ignore[assignment]
            asyncio.create_task(coro_func())
        )

        service._handle_gateway_event(
            {
                "schema": "sb.v1",
                "msg_id": "e6-synced",
                "ts": 1776064500000,
                "tenant_id": "hust",
                "site_id": "lab01",
                "gateway_id": "gw-ubuntu-01",
                "source": "gateway",
                "payload": {
                    "event": "automation_synced",
                    "rule_id": created["id"],
                    "version": 1,
                },
            }
        )
        service._handle_gateway_event(
            {
                "schema": "sb.v1",
                "msg_id": "e6-executed",
                "ts": 1776064501000,
                "tenant_id": "hust",
                "site_id": "lab01",
                "gateway_id": "gw-ubuntu-01",
                "source": "gateway",
                "payload": {
                    "event": "automation_executed",
                    "rule_id": created["id"],
                    "version": 1,
                    "result": "ok",
                    "target_device_id": "light-01",
                },
            }
        )
        await asyncio.gather(*tasks)

        resp = await client.get(
            f"/api/automation-events?automation_id={created['id']}"
        )

        assert resp.status_code == 200
        kinds = [row["event_type"] for row in resp.json()]
        assert "automation_executed" in kinds
        assert "automation_synced" in kinds

        # Rule itself flipped to executed/synced after the events landed.
        rule_resp = await client.get(f"/api/automations/{created['id']}")
        rule = rule_resp.json()
        assert rule["sync_status"] == "synced"
        assert rule["last_run_status"] == "executed"
