import asyncio
import sys
import types
import unittest

from cloud.app.mqtt_client import MQTTService


class _FakeSession:
    def __init__(self):
        self.added = []
        self.committed = False

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, traceback):
        return False

    def add(self, entity):
        self.added.append(entity)

    async def commit(self):
        self.committed = True


class GatewayEventPersistenceTest(unittest.TestCase):
    def test_gateway_online_message_is_saved_as_event_log(self):
        service = MQTTService()
        session = _FakeSession()
        service.set_db_session_factory(lambda: session)
        service._run_async = lambda coro_func: asyncio.run(coro_func())
        fake_models = types.ModuleType("cloud.app.models")
        fake_models.Event = _FakeEvent
        previous_models = sys.modules.get("cloud.app.models")
        sys.modules["cloud.app.models"] = fake_models

        try:
            service._handle_gateway_online(
                {
                    "ts": "2026-05-07T10:12:00+00:00",
                    "gateway_id": "gw-ubuntu-01",
                    "source": "gateway",
                    "payload": {"value": "online"},
                }
            )
        finally:
            if previous_models is None:
                del sys.modules["cloud.app.models"]
            else:
                sys.modules["cloud.app.models"] = previous_models

        self.assertTrue(session.committed)
        self.assertEqual(len(session.added), 1)
        event = session.added[0]
        self.assertIsNone(event.device_id)
        self.assertEqual(event.event_type, "gateway_online")
        self.assertEqual(event.payload["value"], "online")
        self.assertEqual(event.payload["gateway_id"], "gw-ubuntu-01")
        self.assertEqual(event.payload["source"], "gateway")


class _FakeEvent:
    def __init__(self, device_id, event_type, payload, occurred_at):
        self.device_id = device_id
        self.event_type = event_type
        self.payload = payload
        self.occurred_at = occurred_at


if __name__ == "__main__":
    unittest.main()
