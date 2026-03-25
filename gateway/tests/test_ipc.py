"""
Tests for NDJSON IPC encoding and decoding.
"""

from gateway.src.ipc import decode_record, encode_record
from gateway.src.models import IPCRecord


def test_ipc_record_round_trip():
    record = IPCRecord(
        kind="reported",
        source="adapter",
        device_id="light-01",
        payload={"device_id": "light-01", "state": {"power": "on"}},
    )

    encoded = encode_record(record)
    decoded = decode_record(encoded.strip())

    assert decoded.kind == "reported"
    assert decoded.device_id == "light-01"
    assert decoded.payload["state"]["power"] == "on"
