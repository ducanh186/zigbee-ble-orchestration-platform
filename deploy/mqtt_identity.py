from __future__ import annotations

import argparse
import csv
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence


INVENTORY_FIELDS = (
    "principal_id",
    "tenant_id",
    "site_id",
    "gateway_id",
    "csr_file",
)
SAFE_IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
RESERVED_PRINCIPALS = frozenset({"cloud-control", "monitor", "mosquitto"})

GATEWAY_WRITE_TOPICS = (
    "gateway/online",
    "gateway/health",
    "gateway/log",
    "gateway/event",
    "devices/+/+/registry",
    "devices/+/+/reported",
    "devices/+/+/telemetry",
    "devices/+/+/event",
    "devices/+/+/presence",
    "commands/+/reply",
    "ota/devices/+/progress",
    "ota/devices/+/event",
    "groups/+/reported",
    "scenes/+/event",
    "automations/+/reported",
    "automations/+/event",
)
GATEWAY_READ_TOPICS = (
    "devices/+/+/desired",
    "commands/+/request",
    "ota/campaigns/+/manifest",
    "ota/devices/+/desired",
    "groups/+/desired",
    "scenes/+/desired",
    "automations/+/desired",
)


class InventoryError(ValueError):
    """Raised when an MQTT Gateway inventory or CSR is invalid."""


@dataclass(frozen=True)
class GatewayIdentity:
    principal_id: str
    tenant_id: str
    site_id: str
    gateway_id: str
    csr_path: Path

    @property
    def namespace(self) -> str:
        return f"sb/v1/{self.tenant_id}/{self.site_id}/{self.gateway_id}"


def _safe_identifier(value: str, field: str, line_number: int) -> str:
    value = value.strip()
    if not SAFE_IDENTIFIER.fullmatch(value):
        raise InventoryError(
            f"line {line_number}: {field} must match {SAFE_IDENTIFIER.pattern}"
        )
    return value


def _resolve_csr_path(
    inventory_path: Path, value: str, line_number: int
) -> Path:
    normalized_value = value.strip()
    if any(character in value for character in "\t\r\n"):
        raise InventoryError(
            f"line {line_number}: csr_file cannot contain control characters"
        )
    raw_path = Path(normalized_value)
    if not normalized_value or raw_path.is_absolute():
        raise InventoryError(
            f"line {line_number}: csr_file must be a relative path"
        )

    inventory_dir = inventory_path.parent.resolve()
    csr_path = (inventory_dir / raw_path).resolve()
    try:
        csr_path.relative_to(inventory_dir)
    except ValueError as exc:
        raise InventoryError(
            f"line {line_number}: csr_file must stay under {inventory_dir}"
        ) from exc
    return csr_path


def load_inventory(path: str | Path) -> list[GatewayIdentity]:
    inventory_path = Path(path).resolve()
    if not inventory_path.is_file():
        raise InventoryError(f"inventory file does not exist: {inventory_path}")

    entries: list[GatewayIdentity] = []
    principals: set[str] = set()
    namespaces: set[tuple[str, str, str]] = set()

    with inventory_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if tuple(reader.fieldnames or ()) != INVENTORY_FIELDS:
            raise InventoryError(
                "inventory header must be exactly: "
                + ",".join(INVENTORY_FIELDS)
            )

        for line_number, row in enumerate(reader, start=2):
            principal_id = _safe_identifier(
                row["principal_id"], "principal_id", line_number
            )
            if principal_id in RESERVED_PRINCIPALS:
                raise InventoryError(
                    f"line {line_number}: reserved principal_id {principal_id}"
                )
            tenant_id = _safe_identifier(
                row["tenant_id"], "tenant_id", line_number
            )
            site_id = _safe_identifier(row["site_id"], "site_id", line_number)
            gateway_id = _safe_identifier(
                row["gateway_id"], "gateway_id", line_number
            )
            csr_path = _resolve_csr_path(
                inventory_path, row["csr_file"], line_number
            )

            if principal_id in principals:
                raise InventoryError(
                    f"line {line_number}: duplicate principal_id {principal_id}"
                )
            namespace = (tenant_id, site_id, gateway_id)
            if namespace in namespaces:
                raise InventoryError(
                    f"line {line_number}: duplicate namespace "
                    f"{tenant_id}/{site_id}/{gateway_id}"
                )

            principals.add(principal_id)
            namespaces.add(namespace)
            entries.append(
                GatewayIdentity(
                    principal_id=principal_id,
                    tenant_id=tenant_id,
                    site_id=site_id,
                    gateway_id=gateway_id,
                    csr_path=csr_path,
                )
            )

    if not entries:
        raise InventoryError("inventory must contain at least one Gateway")
    return entries


def _run_openssl(arguments: Sequence[str], description: str) -> str:
    try:
        result = subprocess.run(
            ["openssl", *arguments],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise InventoryError("openssl is required to validate Gateway CSRs") from exc

    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise InventoryError(f"{description} failed: {detail}")
    return result.stdout.strip()


def validate_inventory_csrs(entries: Sequence[GatewayIdentity]) -> None:
    for entry in entries:
        if not entry.csr_path.is_file():
            raise InventoryError(
                f"CSR does not exist for {entry.principal_id}: {entry.csr_path}"
            )

        _run_openssl(
            ["req", "-in", str(entry.csr_path), "-noout", "-verify"],
            f"CSR signature validation for {entry.principal_id}",
        )
        subject = _run_openssl(
            [
                "req",
                "-in",
                str(entry.csr_path),
                "-noout",
                "-subject",
                "-nameopt",
                "RFC2253",
            ],
            f"CSR subject validation for {entry.principal_id}",
        )
        common_names = re.findall(
            r"(?:^|,)CN=([^,]+)", subject.removeprefix("subject=")
        )
        if len(common_names) != 1:
            raise InventoryError(
                f"{entry.principal_id} must have exactly one CSR common name"
            )
        common_name = common_names[0]
        if common_name != entry.principal_id:
            raise InventoryError(
                f"CSR common name for {entry.principal_id} must equal "
                f"principal_id; got {common_name!r}"
            )


def _identity_rules(
    principal_id: str,
    namespace: str,
    write_topics: Sequence[str],
    read_topics: Sequence[str],
) -> list[str]:
    lines = [f"user {principal_id}"]
    lines.extend(f"topic write {namespace}/{topic}" for topic in write_topics)
    lines.extend(f"topic read {namespace}/{topic}" for topic in read_topics)
    return lines


def render_acl(entries: Sequence[GatewayIdentity]) -> str:
    ordered_entries = sorted(entries, key=lambda entry: entry.principal_id)
    lines = [
        "# Generated by deploy/mqtt_identity.py. Do not edit.",
        "# Certificate common names are used as Mosquitto usernames.",
        "",
        "user cloud-control",
    ]

    for entry in ordered_entries:
        lines.extend(
            f"topic read {entry.namespace}/{topic}"
            for topic in GATEWAY_WRITE_TOPICS
        )
        lines.extend(
            f"topic write {entry.namespace}/{topic}"
            for topic in GATEWAY_READ_TOPICS
        )

    for entry in ordered_entries:
        lines.append("")
        lines.extend(
            _identity_rules(
                entry.principal_id,
                entry.namespace,
                GATEWAY_WRITE_TOPICS,
                GATEWAY_READ_TOPICS,
            )
        )

    lines.extend(["", "user monitor", "topic read $SYS/#", ""])
    return "\n".join(lines)


def write_acl_atomic(path: str | Path, content: str) -> None:
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_name = tempfile.mkstemp(
        dir=output_path.parent,
        prefix=f".{output_path.name}.",
        text=True,
    )
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, output_path)
    except BaseException:
        Path(temporary_name).unlink(missing_ok=True)
        raise


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate MQTT Gateway CSRs and generate exact Mosquitto ACLs."
    )
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--acl-output", type=Path)
    parser.add_argument(
        "--list",
        action="store_true",
        help="Print validated inventory as tab-separated fields.",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    if not args.acl_output and not args.list:
        raise InventoryError("--acl-output or --list is required")

    entries = load_inventory(args.inventory)
    validate_inventory_csrs(entries)
    if args.acl_output:
        write_acl_atomic(args.acl_output, render_acl(entries))
    if args.list:
        for entry in sorted(entries, key=lambda item: item.principal_id):
            print(
                "\t".join(
                    (
                        entry.principal_id,
                        entry.tenant_id,
                        entry.site_id,
                        entry.gateway_id,
                        str(entry.csr_path),
                    )
                )
            )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except InventoryError as exc:
        raise SystemExit(f"ERROR: {exc}") from exc
