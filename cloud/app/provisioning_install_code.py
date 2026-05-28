from __future__ import annotations

import re
import secrets

_HEX_RE = re.compile(r"^[0-9a-fA-F]+$")
_RAW_INSTALL_CODE_HEX_LENGTHS = {12, 16, 24, 32}
_FULL_INSTALL_CODE_HEX_LENGTHS = {length + 4 for length in _RAW_INSTALL_CODE_HEX_LENGTHS}


def _require_hex(value: str, valid_lengths: set[int], field_name: str) -> str:
    normalized = value.strip().upper()
    if not _HEX_RE.fullmatch(normalized) or len(normalized) not in valid_lengths:
        lengths = ", ".join(str(length) for length in sorted(valid_lengths))
        raise ValueError(f"{field_name} must be hex with length {lengths}")
    return normalized


def _crc16_x25(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0x8408
            else:
                crc >>= 1
            crc &= 0xFFFF
    return crc ^ 0xFFFF


def append_install_code_crc(raw_install_code_hex: str) -> str:
    raw = _require_hex(
        raw_install_code_hex,
        _RAW_INSTALL_CODE_HEX_LENGTHS,
        "raw_install_code_hex",
    )
    crc = _crc16_x25(bytes.fromhex(raw))
    crc_little_endian = f"{crc & 0xFF:02X}{crc >> 8:02X}"
    return raw + crc_little_endian


def validate_install_code(install_code_hex: str) -> bool:
    try:
        full = _require_hex(
            install_code_hex,
            _FULL_INSTALL_CODE_HEX_LENGTHS,
            "install_code_hex",
        )
    except ValueError:
        return False
    return append_install_code_crc(full[:-4]) == full


def normalize_install_code(install_code_hex: str) -> str:
    full = _require_hex(
        install_code_hex,
        _FULL_INSTALL_CODE_HEX_LENGTHS,
        "install_code_hex",
    )
    if not validate_install_code(full):
        raise ValueError("install_code must have a valid Zigbee CRC")
    return full


def generate_install_code(raw_bytes: int = 16) -> str:
    if raw_bytes not in {6, 8, 12, 16}:
        raise ValueError("raw_bytes must be one of 6, 8, 12, 16")
    return append_install_code_crc(secrets.token_hex(raw_bytes))
