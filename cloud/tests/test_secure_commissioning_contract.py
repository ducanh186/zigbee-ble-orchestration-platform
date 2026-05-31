from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMAS = REPO_ROOT / "cloud" / "app" / "schemas.py"
SECURITY_CONFIG = (
    REPO_ROOT
    / "gateway"
    / "Z3GatewayHost"
    / "config"
    / "network-creator-security-config.h"
)
SB_COMMAND_H = REPO_ROOT / "gateway" / "Z3GatewayHost" / "app" / "sb_command.h"
SB_COMMAND_C = REPO_ROOT / "gateway" / "Z3GatewayHost" / "app" / "sb_command.c"
DEVICE_DISPATCH_C = (
    REPO_ROOT / "gateway" / "Z3GatewayHost" / "app" / "device_dispatch.c"
)
COMMISSIONING_DOC = REPO_ROOT / "docs" / "production" / "production-commissioning.md"


def test_cloud_and_gateway_commissioning_bounds_are_secure() -> None:
    schemas = SCHEMAS.read_text(encoding="utf-8")
    security = SECURITY_CONFIG.read_text(encoding="utf-8")

    assert "duration_sec: int = Field(default=180, ge=1, le=180)" in schemas
    assert "BDB_JOIN_USES_INSTALL_CODE_KEY   1" in security
    assert "ALLOW_TC_REJOIN_WITH_WELL_KNOWN_KEY   0" in security
    assert "ALLOW_TC_REJOINS_USING_WELL_KNOWN_KEY_TIMEOUT_SEC   0" in security


def test_gateway_prepare_join_wire_fields_are_parsed() -> None:
    header = SB_COMMAND_H.read_text(encoding="utf-8")
    parser = SB_COMMAND_C.read_text(encoding="utf-8")

    assert "char eui64[17]" in header
    assert "char install_code[37]" in header
    assert 'findQuotedString(body, "\\"eui64\\":' in parser
    assert 'findQuotedString(body, "\\"install_code\\":' in parser


def test_gateway_dispatch_handles_prepare_join_with_install_code() -> None:
    dispatch = DEVICE_DISPATCH_C.read_text(encoding="utf-8")

    assert '"gateway.prepare_join"' in dispatch
    assert "netMgrOpenForJoinSecure" in dispatch
    assert "parseHexEui64" in dispatch
    assert "missing_eui64" in dispatch
    assert "missing_install_code" in dispatch
    assert "bad_install_code" in dispatch
    assert "bad_duration" in dispatch
    assert "memset(icBytes, 0, sizeof(icBytes))" in dispatch


def test_secure_commissioning_runbook_documents_negative_evidence() -> None:
    doc = COMMISSIONING_DOC.read_text(encoding="utf-8").lower()

    assert "install code" in doc
    assert "default global key" in doc
    assert "negative" in doc
    assert "gateway.prepare_join" in doc
