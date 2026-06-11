from __future__ import annotations

import csv
import shutil
import socket
import ssl
import subprocess
import time
from pathlib import Path
from threading import Event
from uuid import uuid4

import paho.mqtt.client as mqtt
import pytest

from deploy.mqtt_identity import load_inventory, render_acl, validate_inventory_csrs


def _run(*arguments: str) -> str:
    result = subprocess.run(
        list(arguments),
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def _docker_available() -> bool:
    if not shutil.which("docker"):
        return False
    result = subprocess.run(
        ["docker", "info"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def _generate_ca(directory: Path) -> tuple[Path, Path]:
    key = directory / "ca.key"
    certificate = directory / "ca.crt"
    _run("openssl", "genrsa", "-out", str(key), "2048")
    _run(
        "openssl",
        "req",
        "-x509",
        "-new",
        "-key",
        str(key),
        "-sha256",
        "-days",
        "1",
        "-subj",
        "/CN=mqtt-isolation-test-ca",
        "-out",
        str(certificate),
    )
    return key, certificate


def _generate_signed_identity(
    directory: Path,
    common_name: str,
    ca_key: Path,
    ca_certificate: Path,
    extension: str,
) -> tuple[Path, Path, Path]:
    key = directory / f"{common_name}.key"
    csr = directory / f"{common_name}.csr"
    certificate = directory / f"{common_name}.crt"
    extension_file = directory / f"{common_name}.ext"
    extension_file.write_text(extension, encoding="utf-8")
    _run("openssl", "genrsa", "-out", str(key), "2048")
    _run(
        "openssl",
        "req",
        "-new",
        "-key",
        str(key),
        "-subj",
        f"/CN={common_name}",
        "-out",
        str(csr),
    )
    _run(
        "openssl",
        "x509",
        "-req",
        "-in",
        str(csr),
        "-CA",
        str(ca_certificate),
        "-CAkey",
        str(ca_key),
        "-CAcreateserial",
        "-out",
        str(certificate),
        "-days",
        "1",
        "-sha256",
        "-extfile",
        str(extension_file),
    )
    return key, csr, certificate


def _reason_value(reason_code: object) -> int:
    value = getattr(reason_code, "value", reason_code)
    return int(value)


def _connect_client(
    port: int,
    ca_certificate: Path,
    certificate: Path,
    key: Path,
) -> mqtt.Client:
    connected = Event()
    connection_result: list[int] = []
    client = mqtt.Client(
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
        client_id=f"isolation-test-{uuid4().hex[:10]}",
        protocol=mqtt.MQTTv5,
    )
    client.tls_set(
        ca_certs=str(ca_certificate),
        certfile=str(certificate),
        keyfile=str(key),
    )

    def on_connect(client, userdata, flags, reason_code, properties):
        connection_result.append(_reason_value(reason_code))
        connected.set()

    client.on_connect = on_connect
    client.connect("127.0.0.1", port)
    client.loop_start()
    assert connected.wait(5), "MQTT client did not connect"
    assert connection_result == [0]
    return client


def _subscribe_reason(client: mqtt.Client, topic: str) -> int:
    completed = Event()
    result: list[int] = []

    def on_subscribe(client, userdata, mid, reason_codes, properties):
        result.extend(_reason_value(code) for code in reason_codes)
        completed.set()

    client.on_subscribe = on_subscribe
    status, _ = client.subscribe(topic, qos=1)
    assert status == mqtt.MQTT_ERR_SUCCESS
    assert completed.wait(5), f"subscription result timed out for {topic}"
    return result[0]


def _publish_reason(client: mqtt.Client, topic: str) -> int:
    completed = Event()
    result: list[int] = []

    def on_publish(client, userdata, mid, reason_code, properties):
        result.append(_reason_value(reason_code))
        completed.set()

    client.on_publish = on_publish
    message = client.publish(topic, "{}", qos=1)
    assert message.rc == mqtt.MQTT_ERR_SUCCESS
    assert completed.wait(5), f"publish result timed out for {topic}"
    return result[0]


def _disconnect(client: mqtt.Client) -> None:
    client.disconnect()
    client.loop_stop()


def _assert_client_without_certificate_rejected(
    port: int, ca_certificate: Path
) -> None:
    connected = Event()
    disconnected = Event()
    unauthenticated = mqtt.Client(
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
        client_id=f"no-certificate-{uuid4().hex[:8]}",
        protocol=mqtt.MQTTv5,
    )
    unauthenticated.tls_set(
        ca_certs=str(ca_certificate),
        cert_reqs=ssl.CERT_REQUIRED,
    )
    unauthenticated.on_connect = (
        lambda client, userdata, flags, reason_code, properties: connected.set()
    )
    unauthenticated.on_disconnect = (
        lambda client, userdata, disconnect_flags, reason_code, properties:
        disconnected.set()
    )

    try:
        unauthenticated.connect("127.0.0.1", port)
    except (OSError, ssl.SSLError):
        return

    unauthenticated.loop_start()
    try:
        assert disconnected.wait(5), "client without a certificate was not rejected"
        assert not connected.is_set()
    finally:
        unauthenticated.loop_stop()


@pytest.mark.skipif(not _docker_available(), reason="Docker daemon is unavailable")
def test_mqtt_certificate_identity_isolates_gateway_namespaces(
    tmp_path: Path,
) -> None:
    ca_key, ca_certificate = _generate_ca(tmp_path)
    client_extension = (
        "basicConstraints=CA:FALSE\n"
        "keyUsage=digitalSignature\n"
        "extendedKeyUsage=clientAuth\n"
    )
    server_extension = (
        "basicConstraints=CA:FALSE\n"
        "keyUsage=digitalSignature,keyEncipherment\n"
        "extendedKeyUsage=serverAuth\n"
        "subjectAltName=DNS:localhost,IP:127.0.0.1\n"
    )
    server_key, _, server_certificate = _generate_signed_identity(
        tmp_path,
        "mosquitto",
        ca_key,
        ca_certificate,
        server_extension,
    )

    identities: dict[str, tuple[Path, Path, Path]] = {}
    for principal in (
        "cloud-control",
        "monitor",
        "gateway-tenant-a-site-1-gw-1",
        "gateway-tenant-b-site-2-gw-2",
        "unknown-client",
    ):
        identities[principal] = _generate_signed_identity(
            tmp_path,
            principal,
            ca_key,
            ca_certificate,
            client_extension,
        )

    inventory = tmp_path / "mqtt-gateways.csv"
    with inventory.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            ("principal_id", "tenant_id", "site_id", "gateway_id", "csr_file")
        )
        writer.writerow(
            (
                "gateway-tenant-a-site-1-gw-1",
                "tenant-a",
                "site-1",
                "gw-1",
                identities["gateway-tenant-a-site-1-gw-1"][1].name,
            )
        )
        writer.writerow(
            (
                "gateway-tenant-b-site-2-gw-2",
                "tenant-b",
                "site-2",
                "gw-2",
                identities["gateway-tenant-b-site-2-gw-2"][1].name,
            )
        )

    entries = load_inventory(inventory)
    validate_inventory_csrs(entries)
    acl = tmp_path / "acl.prod.conf"
    acl.write_text(render_acl(entries), encoding="utf-8")
    configuration = tmp_path / "mosquitto.conf"
    configuration.write_text(
        "\n".join(
            (
                "listener 8883 0.0.0.0",
                "allow_anonymous false",
                "acl_file /test/acl.prod.conf",
                "cafile /test/ca.crt",
                "certfile /test/mosquitto.crt",
                "keyfile /test/mosquitto.key",
                "require_certificate true",
                "use_identity_as_username true",
                "tls_version tlsv1.2",
                "log_dest stdout",
                "",
            )
        ),
        encoding="utf-8",
    )
    tmp_path.chmod(0o755)
    acl.chmod(0o644)
    configuration.chmod(0o644)
    ca_certificate.chmod(0o644)
    server_certificate.chmod(0o644)
    server_key.chmod(0o644)

    container_name = f"mqtt-isolation-{uuid4().hex[:10]}"
    try:
        _run(
            "docker",
            "run",
            "--detach",
            "--rm",
            "--name",
            container_name,
            "--publish",
            "127.0.0.1::8883",
            "--mount",
            f"type=bind,source={tmp_path},target=/test,readonly",
            "eclipse-mosquitto:2.0",
            "mosquitto",
            "-c",
            "/test/mosquitto.conf",
        )
        port_output = _run("docker", "port", container_name, "8883/tcp")
        port = int(port_output.rsplit(":", 1)[1])
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=1):
                    break
            except OSError:
                time.sleep(0.2)
        else:
            pytest.fail("Mosquitto test container did not start")

        gateway_a = _connect_client(
            port,
            ca_certificate,
            identities["gateway-tenant-a-site-1-gw-1"][2],
            identities["gateway-tenant-a-site-1-gw-1"][0],
        )
        assert (
            _subscribe_reason(
                gateway_a,
                "sb/v1/tenant-a/site-1/gw-1/commands/+/request",
            )
            == 1
        )
        assert (
            _publish_reason(
                gateway_a,
                "sb/v1/tenant-a/site-1/gw-1/gateway/event",
            )
            == 0
        )
        assert (
            _subscribe_reason(
                gateway_a,
                "sb/v1/tenant-b/site-2/gw-2/commands/+/request",
            )
            == 135
        )
        assert (
            _publish_reason(
                gateway_a,
                "sb/v1/tenant-b/site-2/gw-2/gateway/event",
            )
            == 135
        )
        _disconnect(gateway_a)

        cloud = _connect_client(
            port,
            ca_certificate,
            identities["cloud-control"][2],
            identities["cloud-control"][0],
        )
        assert (
            _publish_reason(
                cloud,
                "sb/v1/tenant-a/site-1/gw-1/commands/test/request",
            )
            == 0
        )
        assert (
            _publish_reason(
                cloud,
                "sb/v1/tenant-b/site-2/gw-2/commands/test/request",
            )
            == 0
        )
        _disconnect(cloud)

        monitor = _connect_client(
            port,
            ca_certificate,
            identities["monitor"][2],
            identities["monitor"][0],
        )
        assert _subscribe_reason(monitor, "$SYS/broker/uptime") == 1
        assert (
            _subscribe_reason(
                monitor,
                "sb/v1/tenant-a/site-1/gw-1/gateway/health",
            )
            == 135
        )
        _disconnect(monitor)

        unknown = _connect_client(
            port,
            ca_certificate,
            identities["unknown-client"][2],
            identities["unknown-client"][0],
        )
        assert (
            _subscribe_reason(
                unknown,
                "sb/v1/tenant-a/site-1/gw-1/gateway/health",
            )
            == 135
        )
        _disconnect(unknown)

        _assert_client_without_certificate_rejected(port, ca_certificate)
    finally:
        subprocess.run(
            ["docker", "rm", "--force", container_name],
            check=False,
            capture_output=True,
            text=True,
        )
