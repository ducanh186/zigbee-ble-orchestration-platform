"""Generate per-folder CLAUDE.md files across the project.

Root of truth: docs/MQTT_CONTRACT.md
Nested CLAUDE.md files are gitignored (see root .gitignore).
Run from project root: python deploy/gen_claude_md.py
"""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

EXCLUDE_DIR_NAMES = {
    ".git",
    "__pycache__",
    "node_modules",
    "autogen",
    "build",
    ".vscode",
    ".idea",
    "ota-files",
    # Simplicity Studio build outputs / vendor SDK drops
    "gecko_sdk",
    # Mosquitto runtime artefacts (not code)
    "data",
    "passwords",
}
EXCLUDE_PATH_SUBSTR = (
    "gecko_sdk",
    "artifact",
    "ncp-uart-hw-fresh",
    # Obsolete Python gateway bridge (removed in April 2026 refactor — only __pycache__ left)
    "gateway/src",
    "gateway/tests",
    # Flutter scaffold noise — the mobile app is deferred past v1
    "mobile_app/android",
    "mobile_app/ios",
    "mobile_app/linux",
    "mobile_app/macos",
    "mobile_app/windows",
    "mobile_app/web",
    "mobile_app/build",
    # Simplicity Studio per-toolchain output dirs
    "GNU ARM",
)

CONTRACT_REL = "docs/MQTT_CONTRACT.md"

# ---------------------------------------------------------------------------

PROFILES: dict[str, str] = {
    # (path prefix relative to repo root) -> role description
    "": "Monorepo root. Z3Gateway (C, MQTT-native) + cloud (FastAPI + MQTT) + mqtt broker + deploy scripts + docs + Zigbee end-device firmware.",
    "cloud": "FastAPI + MQTT subscriber/publisher + command timeout worker. Async SQLAlchemy 2.0 + asyncpg (Postgres). Entry: `python -m cloud`.",
    "cloud/app": "FastAPI application package: routers, ORM models, Pydantic schemas, MQTT client, command timeout worker, config, seed.",
    "cloud/app/routers": "HTTP endpoint modules (health, devices, events, commands) mounted under /api. See docs/CLOUD_IMPLEMENTATION_PLAN.md.",
    "cloud/tests": "Pytest suite for cloud. AsyncSession + httpx.AsyncClient. Mock MQTT with FakeMQTTPublisher.",
    "cloud/scripts": "Operational scripts: smoke test, payload samples, phase3/phase4 helpers.",
    "cloud/scripts/samples": "Sample MQTT envelopes used by smoke tests — reference only, not runtime data.",
    "gateway": "Z3Gateway host app (C, MQTT-native). Connects to EFR32MG12 NCP via EZSP/ASH and to the cloud via MQTT. No Python bridge — the old IPC/adapter split was removed (see root CLAUDE.md).",
    "gateway/Z3Gateway": "Silicon Labs Z3Gateway project tree. Built via Z3Gateway.Makefile from Simplicity Studio.",
    "gateway/Z3Gateway/Z3GatewayHost": "Host binary: MQTT -> cmd_handler -> device_dispatch -> per-type control (light_ctrl, switch_logic) -> Ember AF API -> NCP over UART.",
    "gateway/Z3Gateway/Z3GatewayHost/app": "C modules: app_mqtt, cmd_handler, device_registry, device_dispatch, light_ctrl, switch_logic, telemetry_rx, device_monitor, net_mgr, rule_engine, sb_command, app_state/log/utils.",
    "gateway/Z3Gateway/Z3GatewayHost/config": "Compile-time config (ZCL, radio, pins). Edit via Simplicity Studio; regenerate autogen on change.",
    "mqtt": "Local Mosquitto broker configuration + docker-compose for dev. Production broker config lives under deploy/.",
    "mqtt/config": "Mosquitto main config + ACL. Principals: gateway (rw), client (read state + write commands), monitor ($SYS read), bridge (local<->EC2).",
    "mqtt/config/conf.d": "Drop-in Mosquitto config fragments (included from mosquitto.conf).",
    "mqtt/docker": "Dev-only Mosquitto container. `docker compose up -d`. Ports 1883 (MQTT) / 9001 (WS).",
    "deploy": "EC2 deploy scripts (PowerShell + bash). docker-compose.prod.yml runs sb-postgres + sb-mosquitto + sb-cloud-api. See root CLAUDE.md troubleshooting section for known deploy pitfalls.",
    "docs": "Architecture contracts + implementation plans. MQTT_CONTRACT.md is the source of truth; OTA_CAMPAIGN_CONTRACT.md governs firmware delivery; DEVICE_CAPABILITY_MATRIX.md maps device types to ZCL clusters.",
    "database": "Postgres schema.sql / dev fixtures. Cloud ORM models in cloud/app/models.py are the runtime source.",
    "end_devices": "Zigbee end-device firmware (Silicon Labs EFR32MG12 + Gecko SDK). One Simplicity Studio project per device type.",
    "end_devices/Z3Light": "Light end-device firmware. On/Off cluster (0x0006) at endpoint 1: ON=0x01, OFF=0x00, TOGGLE=0x02.",
    "end_devices/Z3Light/app": "Application C sources for Z3Light.",
    "end_devices/Z3Switch": "Switch end-device firmware. Emits toggle events via Zigbee to be relayed as MQTT events by the gateway.",
    "end_devices/Z3Switch/app": "Application C sources for Z3Switch.",
    "end_devices/Z3_Occupancy_Sensor": "Occupancy sensor firmware. Occupancy Sensing cluster (0x0406). Deferred past v1.",
    "end_devices/Z3_Occupancy_Sensor/app": "Application C sources for the occupancy sensor.",
    "mobile_app": "Flutter app placeholder. Deferred past v1 — platform scaffold (android/ios/web/etc.) is excluded from CLAUDE.md generation.",
}

CLUSTER_HINTS = {
    "app": "Application C sources. Z3Light uses ZCL On/Off cluster 0x0006 at endpoint 1.",
    "config": "Project configuration (pin tool, ZCL, radio config). Edit via Simplicity Studio; regenerate autogen on change.",
    "config/zcl": "ZCL endpoint + cluster definitions for this device.",
    "routers": "FastAPI router modules.",
}


def matches_exclude(path: Path) -> bool:
    parts = path.parts
    if any(p in EXCLUDE_DIR_NAMES for p in parts):
        return True
    s = str(path).replace("\\", "/")
    if any(sub in s for sub in EXCLUDE_PATH_SUBSTR):
        return True
    return False


def folder_role(rel: str) -> str:
    # Prefer exact match, then nearest prefix
    if rel in PROFILES:
        return PROFILES[rel]
    segs = rel.split("/")
    for cut in range(len(segs) - 1, 0, -1):
        prefix = "/".join(segs[:cut])
        if prefix in PROFILES:
            break
    else:
        prefix = ""
    parent_desc = PROFILES.get(prefix, "Project subfolder.")
    last = segs[-1] if segs else ""
    hint = CLUSTER_HINTS.get(last)
    pieces = [f"Subfolder of `{prefix or 'repo root'}`.", parent_desc]
    if hint:
        pieces.append(hint)
    return " ".join(pieces)


def list_children(path: Path) -> tuple[list[str], list[str]]:
    dirs, files = [], []
    try:
        for entry in sorted(path.iterdir()):
            if entry.name.startswith("."):
                continue
            if entry.is_dir():
                if entry.name in EXCLUDE_DIR_NAMES:
                    continue
                rel_child = entry.relative_to(ROOT).as_posix()
                if any(sub in rel_child for sub in EXCLUDE_PATH_SUBSTR):
                    continue
                dirs.append(entry.name + "/")
            else:
                if entry.name in {"CLAUDE.md"}:
                    continue
                files.append(entry.name)
    except PermissionError:
        pass
    return dirs, files


def make_content(rel: str, path: Path) -> str:
    role = folder_role(rel)
    dirs, files = list_children(path)
    dir_line = ", ".join(dirs) if dirs else "(no subfolders)"
    file_line = ", ".join(files[:40]) if files else "(no files)"
    if len(files) > 40:
        file_line += f", …(+{len(files) - 40} more)"
    depth = 0 if rel == "" else rel.count("/") + 1
    back_to_root = "../" * depth if depth else "./"
    contract = f"{back_to_root}{CONTRACT_REL}"
    header_path = rel or "."
    return f"""# CLAUDE.md — `{header_path}`

**Role:** {role}

**Protocol source of truth:** [{CONTRACT_REL}]({contract}).
All MQTT publishers/subscribers in this folder MUST follow that contract:
- Namespace `sb/v1/{{tenant}}/{{site}}/{{gateway}}/...`
- Envelope fields `schema, msg_id, ts, tenant_id, site_id, gateway_id, source, payload` (+ optional `trace_id`, `correlation_id`)
- Command lifecycle `accepted → queued → sent → executed | failed | timeout`
- Identity: `device_id` primary (logical, stable), `eui64` hardware, `nwk_addr` debug-only (never a key)

## Contents

- Subfolders: {dir_line}
- Files: {file_line}

## Rules for edits inside this folder

1. Do not invent new MQTT topics/channel names; extend only per contract §"Quy tắc thiết kế".
2. `device_type` lives in the topic segment AND in payload — keep both in sync.
3. Commands must carry `correlation_id = command_id` on every reply.
4. Never publish firmware binaries over MQTT — OTA uses artifact URL + SHA256 per `docs/OTA_CAMPAIGN_CONTRACT.md`.
5. Cloud (Python): prefer editing existing modules; run `pytest cloud/tests/` before commit.
6. Z3Gateway (C): southbound to the NCP is EZSP/ASH owned by Z3Gateway — do NOT add custom UART framing. Northbound is MQTT directly (no Unix socket, no NDJSON IPC — the Python bridge was removed in April 2026).
7. End-device firmware: ZCL clusters per `docs/DEVICE_CAPABILITY_MATRIX.md`; regenerate Simplicity Studio autogen after `.slcp`/ZAP changes.

## Current phase (2026-04)

Phase 6 — Gateway ↔ cloud end-to-end over MQTT on EC2. Recent milestones:
- Python MQTT↔IPC bridge removed; Z3Gateway C speaks MQTT directly (commit `c4e672f`).
- Downstream command path complete (cloud → gateway → Zigbee light), including normalized MQTT contract handling.
- Per-type control modules landed in gateway adapter (device registry, dispatch, light_ctrl, switch_logic).

Active scope:
- Event/telemetry round-trip coverage (reported/event/reply envelopes)
- Command timeout worker + lifecycle states in cloud
- EC2 deploy stability (see deploy troubleshooting in root CLAUDE.md)

> This file is auto-generated by `deploy/gen_claude_md.py` and is gitignored.
"""


def main() -> int:
    created = 0
    removed = 0
    # First pass: remove stale CLAUDE.md files under now-excluded paths.
    for dirpath, _, _ in os.walk(ROOT):
        p = Path(dirpath)
        rel = p.relative_to(ROOT)
        if p != ROOT and matches_exclude(rel):
            stale = p / "CLAUDE.md"
            if stale.exists():
                stale.unlink()
                removed += 1
    # Second pass: regenerate for kept dirs.
    for dirpath, dirnames, _ in os.walk(ROOT):
        dirnames[:] = [
            d for d in dirnames
            if not d.startswith(".")
            and d not in EXCLUDE_DIR_NAMES
            and not any(sub in (Path(dirpath) / d).as_posix() for sub in EXCLUDE_PATH_SUBSTR)
        ]
        p = Path(dirpath)
        if matches_exclude(p.relative_to(ROOT)) and p != ROOT:
            continue
        rel = p.relative_to(ROOT).as_posix() if p != ROOT else ""
        if rel == "":
            # Skip root: repo has a hand-maintained CLAUDE.md at root.
            continue
        target = p / "CLAUDE.md"
        content = make_content(rel, p)
        target.write_text(content, encoding="utf-8", newline="\n")
        created += 1
    print(f"Wrote {created} CLAUDE.md files; removed {removed} stale.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
