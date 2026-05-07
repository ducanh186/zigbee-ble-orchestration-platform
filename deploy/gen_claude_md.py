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
}
EXCLUDE_PATH_SUBSTR = (
    "gecko_sdk",
    "artifact",
    "ncp-uart-hw-fresh",
)

CONTRACT_REL = "docs/MQTT_CONTRACT.md"

# ---------------------------------------------------------------------------

PROFILES: dict[str, str] = {
    # (path prefix relative to repo root) -> role description
    "": "Monorepo root. Contains gateway (native C Z3Gateway with direct MQTT), cloud (FastAPI + MQTT), mqtt (broker config), deploy (EC2 scripts), docs, end_devices (firmware), mobile_app.",
    "cloud": "FastAPI + MQTT subscriber/publisher for cloud-side device management. Async SQLAlchemy 2.0 + asyncpg. Entry: `python -m cloud`.",
    "cloud/app": "FastAPI application package: routers, ORM models, MQTT client, config, database session, Pydantic schemas, seed.",
    "cloud/app/routers": "HTTP endpoint modules: health, devices, events, commands. Each router mounts under /api.",
    "cloud/tests": "Pytest suite for cloud. Use AsyncSession + httpx.AsyncClient. Mock MQTT with FakeMQTTPublisher.",
    "cloud/scripts": "Operational scripts: smoke test, payload samples, data dump helpers.",
    "gateway": "Production gateway implementation: native C single-process Z3Gateway host with direct MQTT; no custom MQTT <-> IPC bridge.",
    "gateway/tests": "Tests for gateway components and integrations.",
    "gateway/Z3Gateway": "Native Z3Gateway host code (Silicon Labs). SOUTHBOUND BOUNDARY is Ember AF / Z3Gateway C API (emberAfSendCommandUnicast etc.) — NOT custom IPC.",
    "gateway/Z3Gateway/Z3GatewayHost": "Host-side Z3Gateway app: MQTT -> cmd_handler -> device dispatch -> Ember AF.",
    "gateway/Z3Gateway/Z3GatewayHost/app": "C modules. Refactor target: app_mqtt.c, cmd_handler.c (parse+dispatch only), device_registry, device_dispatch, light_ctrl, switch_logic.",
    "mqtt": "Local Mosquitto broker configuration + docker-compose for dev.",
    "mqtt/docker": "Dev-only Mosquitto container. `docker compose up -d`. Ports 1883 (MQTT) / 9001 (WS).",
    "deploy": "EC2 deploy scripts (PowerShell + bash). docker-compose.prod.yml runs sb-mosquitto + sb-cloud-api.",
    "docs": "Architecture contracts and planning docs. MQTT_CONTRACT.md is the source of truth.",
    "database": "Postgres init SQL / schema snapshots for dev.",
    "end_devices": "Zigbee end device firmware projects (Z3Light, Z3Switch, Z3_Occupancy_Sensor). EFR32MG12 + Gecko SDK.",
    "end_devices/Z3Light": "Light end device firmware. Supports On/Off cluster (0x0006) at endpoint 1.",
    "end_devices/Z3Switch": "Switch end device firmware. Publishes toggle events via Zigbee.",
    "end_devices/Z3_Occupancy_Sensor": "Occupancy sensor firmware (deferred past v1).",
    "mobile_app": "Mobile app placeholder (Flutter planned, deferred past v1).",
}

CLUSTER_HINTS = {
    "app": "Application C sources. Light uses ZCL cluster 0x0006 (On/Off): ON=0x01, OFF=0x00.",
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
- Identity: `device_id` primary, `eui64` hardware, `nwk_addr` debug-only

## Contents

- Subfolders: {dir_line}
- Files: {file_line}

## Rules for edits inside this folder

1. Do not invent new MQTT topics/channel names; extend only per contract §"Quy tắc thiết kế".
2. `device_type` lives in the topic segment AND in payload — keep both in sync.
3. Commands must carry `correlation_id = command_id` on every reply.
4. Never publish firmware binaries over MQTT — OTA uses artifact URL + SHA256 per `docs/OTA_CAMPAIGN_CONTRACT.md`.
5. Python: prefer editing existing modules; run pytest before commit.
6. C (Z3Gateway): southbound boundary is Ember AF API — do NOT reintroduce custom UART frames.

## Current phase (2026-04)

Phase 5 — Cloud API hardening + EC2 demo. Scope:
- Command timeout worker in cloud
- Smoke test hitting `POST /api/devices/{{id}}/command` end-to-end
- Cloud pytest coverage on routers + mqtt_client
- Deploy + verify on EC2 via `deploy/deploy.ps1`

> This file is auto-generated by `deploy/gen_claude_md.py` and is gitignored.
"""


def main() -> int:
    created = 0
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
    print(f"Wrote {created} CLAUDE.md files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
