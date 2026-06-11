from __future__ import annotations

import csv
import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

from deploy.mqtt_identity import (
    InventoryError,
    load_inventory,
    render_acl,
    validate_inventory_csrs,
)


def _write_inventory(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "principal_id",
                "tenant_id",
                "site_id",
                "gateway_id",
                "csr_file",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)


def _row(
    principal_id: str = "gateway-hust-lab01-01",
    tenant_id: str = "hust",
    site_id: str = "lab01",
    gateway_id: str = "gw-ubuntu-01",
    csr_file: str = "csrs/gateway-hust-lab01-01.csr",
) -> dict[str, str]:
    return {
        "principal_id": principal_id,
        "tenant_id": tenant_id,
        "site_id": site_id,
        "gateway_id": gateway_id,
        "csr_file": csr_file,
    }


def _generate_csr(path: Path, common_name: str) -> None:
    key = path.with_suffix(".key")
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "openssl",
            "req",
            "-new",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            str(key),
            "-out",
            str(path),
            "-subj",
            f"/CN={common_name}",
        ],
        check=True,
        capture_output=True,
        text=True,
    )


def _find_working_bash() -> str | None:
    candidates = [shutil.which("bash")]
    git = shutil.which("git")
    if os.name == "nt" and git:
        git_root = Path(git).resolve().parent.parent
        candidates.extend(
            (
                str(git_root / "bin" / "bash.exe"),
                r"C:\Program Files\Git\bin\bash.exe",
                r"C:\msys64\usr\bin\bash.exe",
            )
        )

    for candidate in dict.fromkeys(item for item in candidates if item):
        result = subprocess.run(
            [candidate, "-lc", "printf ready"],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout == "ready":
            return candidate
    return None


def _bash_path(bash: str, path: Path) -> str:
    if os.name != "nt":
        return str(path)
    return subprocess.run(
        [bash, "-lc", 'cygpath -u "$1"', "_", str(path)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def test_load_inventory_rejects_duplicate_principal(tmp_path: Path) -> None:
    inventory = tmp_path / "gateways.csv"
    _write_inventory(
        inventory,
        [
            _row(),
            _row(site_id="lab02", gateway_id="gw-ubuntu-02"),
        ],
    )

    with pytest.raises(InventoryError, match="duplicate principal_id"):
        load_inventory(inventory)


def test_load_inventory_rejects_duplicate_namespace(tmp_path: Path) -> None:
    inventory = tmp_path / "gateways.csv"
    _write_inventory(
        inventory,
        [
            _row(),
            _row(principal_id="gateway-hust-lab01-02"),
        ],
    )

    with pytest.raises(InventoryError, match="duplicate namespace"):
        load_inventory(inventory)


def test_load_inventory_rejects_unsafe_identifier(tmp_path: Path) -> None:
    inventory = tmp_path / "gateways.csv"
    _write_inventory(inventory, [_row(tenant_id="tenant/escape")])

    with pytest.raises(InventoryError, match="tenant_id"):
        load_inventory(inventory)


@pytest.mark.parametrize("principal_id", ["cloud-control", "monitor", "mosquitto"])
def test_load_inventory_rejects_reserved_principal(
    tmp_path: Path, principal_id: str
) -> None:
    inventory = tmp_path / "gateways.csv"
    _write_inventory(inventory, [_row(principal_id=principal_id)])

    with pytest.raises(InventoryError, match="reserved principal_id"):
        load_inventory(inventory)


@pytest.mark.parametrize("csr_file", ["../gateway.csr", "/tmp/gateway.csr"])
def test_load_inventory_rejects_csr_path_escape(
    tmp_path: Path, csr_file: str
) -> None:
    inventory = tmp_path / "gateways.csv"
    _write_inventory(inventory, [_row(csr_file=csr_file)])

    with pytest.raises(InventoryError, match="csr_file"):
        load_inventory(inventory)


def test_load_inventory_rejects_csr_control_characters(
    tmp_path: Path,
) -> None:
    inventory = tmp_path / "gateways.csv"
    _write_inventory(inventory, [_row(csr_file="csrs/gateway.csr\tother")])

    with pytest.raises(InventoryError, match="control characters"):
        load_inventory(inventory)


def test_validate_inventory_csrs_rejects_cn_mismatch(tmp_path: Path) -> None:
    inventory = tmp_path / "gateways.csv"
    csr = tmp_path / "csrs" / "gateway.csr"
    _generate_csr(csr, "different-principal")
    _write_inventory(inventory, [_row(csr_file="csrs/gateway.csr")])
    entries = load_inventory(inventory)

    with pytest.raises(InventoryError, match="CSR common name"):
        validate_inventory_csrs(entries)


def test_validate_inventory_csrs_accepts_matching_cn(tmp_path: Path) -> None:
    inventory = tmp_path / "gateways.csv"
    csr = tmp_path / "csrs" / "gateway.csr"
    _generate_csr(csr, "gateway-hust-lab01-01")
    _write_inventory(inventory, [_row(csr_file="csrs/gateway.csr")])

    validate_inventory_csrs(load_inventory(inventory))


def test_validate_inventory_csrs_rejects_multiple_common_names(
    tmp_path: Path,
) -> None:
    inventory = tmp_path / "gateways.csv"
    csr = tmp_path / "csrs" / "gateway.csr"
    key = csr.with_suffix(".key")
    csr.parent.mkdir(parents=True)
    subprocess.run(
        [
            "openssl",
            "req",
            "-new",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            str(key),
            "-out",
            str(csr),
            "-subj",
            "/CN=gateway-hust-lab01-01/CN=monitor",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    _write_inventory(inventory, [_row(csr_file="csrs/gateway.csr")])

    with pytest.raises(InventoryError, match="exactly one CSR common name"):
        validate_inventory_csrs(load_inventory(inventory))


def test_render_acl_is_deterministic_and_namespace_exact(tmp_path: Path) -> None:
    inventory = tmp_path / "gateways.csv"
    _write_inventory(
        inventory,
        [
            _row(
                principal_id="gateway-tenant-b-site-2-gw-2",
                tenant_id="tenant-b",
                site_id="site-2",
                gateway_id="gw-2",
                csr_file="csrs/gw-2.csr",
            ),
            _row(
                principal_id="gateway-tenant-a-site-1-gw-1",
                tenant_id="tenant-a",
                site_id="site-1",
                gateway_id="gw-1",
                csr_file="csrs/gw-1.csr",
            ),
        ],
    )

    acl = render_acl(load_inventory(inventory))

    assert acl.index("user gateway-tenant-a-site-1-gw-1") < acl.index(
        "user gateway-tenant-b-site-2-gw-2"
    )
    assert "user cloud-control" in acl
    assert "user monitor\ntopic read $SYS/#" in acl
    assert "sb/v1/+/+/+/" not in acl
    assert "topic write sb/v1/tenant-a/site-1/gw-1/devices/+/+/reported" in acl
    assert "topic read sb/v1/tenant-a/site-1/gw-1/commands/+/request" in acl
    assert "topic write sb/v1/tenant-b/site-2/gw-2/commands/+/request" in acl


def test_setup_failure_keeps_existing_acl_unchanged(tmp_path: Path) -> None:
    bash = _find_working_bash()
    if not bash:
        pytest.skip("bash is required for the deployment script contract")

    repository_root = Path(__file__).resolve().parents[2]
    inventory = tmp_path / "gateways.csv"
    _write_inventory(
        inventory,
        [
            _row(),
            _row(site_id="lab02", gateway_id="gw-ubuntu-02"),
        ],
    )
    acl = tmp_path / "generated" / "acl.prod.conf"
    acl.parent.mkdir()
    acl.write_text("active-acl\n", encoding="utf-8")
    pki = tmp_path / "pki"
    environment = os.environ.copy()
    environment.update({"MOSQUITTO_UID": "1883", "MOSQUITTO_GID": "1883"})
    if os.name == "nt":
        environment["MSYS2_ARG_CONV_EXCL"] = "/CN="

    result = subprocess.run(
        [
            bash,
            _bash_path(
                bash, repository_root / "deploy" / "setup-mqtt-mtls.sh"
            ),
            _bash_path(bash, repository_root),
            "localhost",
            _bash_path(bash, pki),
            _bash_path(bash, inventory),
            _bash_path(bash, acl),
        ],
        check=False,
        capture_output=True,
        text=True,
        env=environment,
    )

    assert result.returncode != 0
    assert acl.read_text(encoding="utf-8") == "active-acl\n"
    assert not pki.exists()


def test_setup_signs_gateway_csr_and_generates_required_outputs(
    tmp_path: Path,
) -> None:
    bash = _find_working_bash()
    if not bash:
        pytest.skip("bash is required for the deployment script contract")

    repository_root = Path(__file__).resolve().parents[2]
    csr = tmp_path / "csrs" / "gateway.csr"
    _generate_csr(csr, "gateway-hust-lab01-01")
    inventory = tmp_path / "gateways.csv"
    _write_inventory(inventory, [_row(csr_file="csrs/gateway.csr")])
    pki = tmp_path / "pki"
    acl = tmp_path / "generated" / "acl.prod.conf"
    user_id = subprocess.run(
        [bash, "-lc", "id -u"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    group_id = subprocess.run(
        [bash, "-lc", "id -g"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    environment = os.environ.copy()
    environment.update(
        {"MOSQUITTO_UID": user_id, "MOSQUITTO_GID": group_id}
    )
    if os.name == "nt":
        environment["MSYS2_ARG_CONV_EXCL"] = "/CN="

    subprocess.run(
        [
            bash,
            _bash_path(
                bash, repository_root / "deploy" / "setup-mqtt-mtls.sh"
            ),
            _bash_path(bash, repository_root),
            "localhost",
            _bash_path(bash, pki),
            _bash_path(bash, inventory),
            _bash_path(bash, acl),
        ],
        check=True,
        capture_output=True,
        text=True,
        env=environment,
    )

    gateway_certificate = (
        pki / "gateways" / "gateway-hust-lab01-01.crt"
    )
    assert gateway_certificate.is_file()
    assert not list((pki / "gateways").glob("*.key"))
    assert (pki / "clients" / "cloud-control.crt").is_file()
    assert (pki / "clients" / "cloud-control.key").is_file()
    assert (pki / "clients" / "monitor.crt").is_file()
    assert (pki / "clients" / "monitor.key").is_file()
    assert (pki / "server" / "server.crt").is_file()
    assert (pki / "server" / "server.key").is_file()
    assert "user gateway-hust-lab01-01" in acl.read_text(encoding="utf-8")
    subprocess.run(
        [
            "openssl",
            "verify",
            "-CAfile",
            str(pki / "ca" / "ca.crt"),
            str(gateway_certificate),
        ],
        check=True,
        capture_output=True,
        text=True,
    )

    if os.name != "nt":
        assert stat.S_IMODE((pki / "ca" / "ca.key").stat().st_mode) == 0o600
        assert (
            stat.S_IMODE(
                (pki / "clients" / "cloud-control.key").stat().st_mode
            )
            == 0o600
        )
        assert (
            stat.S_IMODE((pki / "server" / "server.key").stat().st_mode)
            == 0o640
        )
        assert (
            stat.S_IMODE((pki / "clients" / "monitor.key").stat().st_mode)
            == 0o640
        )
