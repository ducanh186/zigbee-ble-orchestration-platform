#!/usr/bin/env python3
"""Collect post-test JSON evidence dumps from cloud REST API + MQTT capture.

Run after gateway uplink test. Reads test_start.txt for window, intersects with
MQTT capture and DB rows, and produces a numbered evidence bundle in this
directory.
"""
import datetime as dt
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

EVIDIR = Path(__file__).resolve().parent
API = "http://localhost:8000"


def fetch(path: str):
    with urllib.request.urlopen(API + path, timeout=5) as r:
        return json.load(r)


def parse_ndjson(p: Path):
    out = []
    if not p.exists():
        return out
    for line in p.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line or not line.startswith("{"):
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            # Some payloads have raw JSON; the format string emits payload as-is.
            # Reconstruct manually with a regex fallback.
            m = re.match(r'\{"ts":"([^"]+)","topic":"([^"]+)","retained":(\d+),"qos":(\d+),"payload":(.*)\}\Z', line)
            if m:
                ts, topic, ret, qos, payload = m.groups()
                try:
                    payload_obj = json.loads(payload) if payload.startswith("{") or payload.startswith("[") else payload
                except Exception:
                    payload_obj = payload
                out.append({"ts": ts, "topic": topic, "retained": int(ret), "qos": int(qos), "payload": payload_obj})
    return out


def main():
    start_txt = (EVIDIR / "test_start.txt").read_text().strip()
    test_start_dt = dt.datetime.fromisoformat(start_txt)

    captured_at = dt.datetime.now(test_start_dt.tzinfo).isoformat()

    mqtt_records = parse_ndjson(EVIDIR / "02_mqtt_capture.ndjson")
    # Filter only messages received AFTER test_start (drop any retained replays
    # sent before our test started). The mosquitto_sub %I timestamp is ISO8601.
    fresh = []
    retained_seen = []
    for r in mqtt_records:
        try:
            r_dt = dt.datetime.fromisoformat(r["ts"])
        except Exception:
            continue
        if r.get("retained"):
            retained_seen.append(r)
        if r_dt >= test_start_dt:
            fresh.append(r)

    by_topic = {}
    for r in fresh:
        by_topic.setdefault(r["topic"], []).append(r)

    # Identify distinct real device EUI64s seen in registry/reported during test.
    eui_pat = re.compile(r"/devices/(light|switch|occupancy_sensor)/([0-9a-fA-F]{16})/(registry|reported|event)$")
    devices_seen = {}
    for t, rs in by_topic.items():
        m = eui_pat.search(t)
        if not m:
            continue
        dtype, eui, kind = m.groups()
        d = devices_seen.setdefault(eui, {"device_type": dtype, "topics": {}})
        d["topics"].setdefault(kind, 0)
        d["topics"][kind] += len(rs)

    # Cloud REST API state.
    health = fetch("/health")
    devices = fetch("/api/devices/")
    events_recent = fetch("/api/events/")

    # Per-device REST detail dump for the EUI64s the gateway saw during test.
    def fetch_or_none(p):
        try:
            return fetch(p)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return {"_note": f"404 for {p} — expected when no row exists yet"}
            raise

    device_detail = {}
    for eui in devices_seen:
        # Find device_id by eui64 match.
        for d in devices:
            if d.get("eui64") and d["eui64"].lower() == eui.lower():
                did = d["id"]
                device_detail[eui] = {
                    "device": fetch_or_none(f"/api/devices/{did}"),
                    "state": fetch_or_none(f"/api/devices/{did}/state"),
                }

    summary = {
        "captured_at": captured_at,
        "test_window_start": start_txt,
        "stack_versions": {
            "ezsp_stack": "7.5.1 GA build 0",
            "mosquitto": "2.0.22",
            "cloud_health": health,
        },
        "mqtt_capture": {
            "total_messages": len(mqtt_records),
            "messages_during_test": len(fresh),
            "messages_retained_seen": len(retained_seen),
            "topics_seen_during_test": sorted(by_topic.keys()),
            "topic_message_counts": {t: len(rs) for t, rs in sorted(by_topic.items())},
            "devices_seen_real_eui64": devices_seen,
        },
        "rest_api": {
            "GET /health": health,
            "GET /api/devices/ (count)": len(devices),
            "GET /api/devices/ (real_eui64_only)": [d for d in devices if d.get("eui64")],
            "GET /api/events/ (count)": len(events_recent),
            "GET /api/events/ (sample_first5)": events_recent[:5],
            "per_device_detail": device_detail,
        },
        "verdict": (
            "PASS — real device uplink end-to-end" if len(devices_seen) >= 1 else
            "INCONCLUSIVE — no real-device registry/reported/event observed during test window"
        ),
    }

    out_path = EVIDIR / "03_post_test_summary.json"
    out_path.write_text(json.dumps(summary, indent=2, default=str, ensure_ascii=False))

    # Also write the full filtered MQTT capture during test window.
    fresh_path = EVIDIR / "04_mqtt_during_test.json"
    fresh_path.write_text(json.dumps(fresh, indent=2, default=str, ensure_ascii=False))

    # Per-device topic dump for easy mentor read-along.
    for eui, info in devices_seen.items():
        per_dev = {
            "device_type": info["device_type"],
            "eui64": eui,
            "messages": [r for r in fresh if eui in r["topic"]],
            "rest_api_detail": device_detail.get(eui),
        }
        (EVIDIR / f"05_device_{info['device_type']}_{eui}.json").write_text(
            json.dumps(per_dev, indent=2, default=str, ensure_ascii=False)
        )

    print(f"wrote {out_path}")
    print(f"wrote {fresh_path}")
    print(f"per-device files: {len(devices_seen)}")
    print(json.dumps(summary["mqtt_capture"]["devices_seen_real_eui64"], indent=2))
    print("VERDICT:", summary["verdict"])


if __name__ == "__main__":
    main()
