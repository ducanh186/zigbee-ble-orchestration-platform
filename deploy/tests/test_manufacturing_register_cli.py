from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
POWERSHELL_SCRIPT = REPO_ROOT / "deploy" / "manufacturing-register.ps1"
BASH_SCRIPT = REPO_ROOT / "deploy" / "manufacturing-register.sh"

EUI64 = "A8D417FEFF570B00"
INSTALL_CODE = "83FED3407A939723A5C639B26916D505C3B5"
ACCESS_TOKEN = "manufacturing-token-must-not-leak"


def _find_working_bash() -> str | None:
    candidates = [
        shutil.which("bash"),
        str(Path(os.environ.get("ProgramFiles", "")) / "Git" / "bin" / "bash.exe"),
        str(
            Path(os.environ.get("LOCALAPPDATA", ""))
            / "Programs"
            / "Git"
            / "bin"
            / "bash.exe"
        ),
    ]
    for candidate in candidates:
        if not candidate or not Path(candidate).is_file():
            continue
        probe = subprocess.run(
            [candidate, "--version"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if probe.returncode == 0:
            return candidate
    return None


def _bash_path(path: Path) -> str:
    resolved = path.resolve()
    if resolved.drive:
        return f"/{resolved.drive[0].lower()}{resolved.as_posix()[2:]}"
    return resolved.as_posix()


class _MockCloud:
    def __init__(self) -> None:
        self.requests: list[dict[str, object]] = []
        self.fail_factory = False
        self._server = ThreadingHTTPServer(("127.0.0.1", 0), self._handler())
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)

    @property
    def base_url(self) -> str:
        host, port = self._server.server_address
        return f"http://{host}:{port}"

    def start(self) -> None:
        self._thread.start()

    def close(self) -> None:
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=5)

    def _handler(self):
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self) -> None:
                length = int(self.headers.get("content-length", "0"))
                raw_body = self.rfile.read(length)
                body = json.loads(raw_body.decode("utf-8"))
                owner.requests.append(
                    {
                        "path": self.path,
                        "body": body,
                        "authorization": self.headers.get("authorization"),
                    }
                )

                if (
                    self.path == "/api/provisioning/factory-devices"
                    and owner.fail_factory
                ):
                    self._send_json(
                        500,
                        {
                            "detail": (
                                f"must stay hidden: {INSTALL_CODE} {ACCESS_TOKEN}"
                            )
                        },
                    )
                    return

                if self.path == "/api/provisioning/factory-devices":
                    self._send_json(
                        201,
                        {
                            "eui64": EUI64,
                            "device_type": "light",
                            "model": "EFR32MG12_LIGHT_KIT",
                            "is_active": True,
                            "has_install_code": True,
                        },
                    )
                    return

                if self.path == "/api/provisioning/labels":
                    payload = {
                        "version": 1,
                        "eui64": EUI64,
                        "device_type": "light",
                    }
                    self._send_json(
                        201,
                        {
                            "payload": payload,
                            "payload_json": json.dumps(
                                payload, separators=(",", ":")
                            ),
                            "qr_svg": (
                                '<?xml version="1.0" encoding="UTF-8"?>'
                                '<svg xmlns="http://www.w3.org/2000/svg"></svg>'
                            ),
                        },
                    )
                    return

                self._send_json(404, {"detail": "not found"})

            def log_message(self, _format: str, *args: object) -> None:
                return

            def _send_json(self, status: int, payload: dict[str, object]) -> None:
                encoded = json.dumps(payload).encode("utf-8")
                self.send_response(status)
                self.send_header("content-type", "application/json")
                self.send_header("content-length", str(len(encoded)))
                self.end_headers()
                self.wfile.write(encoded)

        return Handler


class _ManufacturingCliContract:
    script_path: Path

    def setUp(self) -> None:
        self.cloud = _MockCloud()
        self.cloud.start()
        self.temp_dir = tempfile.TemporaryDirectory()
        self.output_dir = Path(self.temp_dir.name) / "label"
        self.env = os.environ.copy()
        self.env["SB_API_BASE_URL"] = self.cloud.base_url
        self.env["SB_MANUFACTURING_ACCESS_TOKEN"] = ACCESS_TOKEN

    def tearDown(self) -> None:
        self.cloud.close()
        self.temp_dir.cleanup()

    def build_command(self, output_dir: Path) -> list[str]:
        raise NotImplementedError

    def run_cli(
        self,
        *,
        env: dict[str, str] | None = None,
        output_dir: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            self.build_command(output_dir or self.output_dir),
            cwd=REPO_ROOT,
            env=env or self.env,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )

    def assert_secrets_hidden(self, result: subprocess.CompletedProcess[str]) -> None:
        combined = result.stdout + result.stderr
        self.assertNotIn(INSTALL_CODE, combined)
        self.assertNotIn(ACCESS_TOKEN, combined)

    def test_registers_secret_then_generates_public_label(self) -> None:
        result = self.run_cli()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_secrets_hidden(result)
        self.assertEqual(
            [request["path"] for request in self.cloud.requests],
            [
                "/api/provisioning/factory-devices",
                "/api/provisioning/labels",
            ],
        )

        factory_request, label_request = self.cloud.requests
        self.assertEqual(
            factory_request["authorization"], f"Bearer {ACCESS_TOKEN}"
        )
        self.assertEqual(factory_request["body"]["install_code"], INSTALL_CODE)
        self.assertEqual(factory_request["body"]["model"], "EFR32MG12_LIGHT_KIT")

        self.assertEqual(label_request["authorization"], f"Bearer {ACCESS_TOKEN}")
        self.assertEqual(
            label_request["body"],
            {"eui64": EUI64, "device_type": "light"},
        )

        payload_text = (self.output_dir / "payload.json").read_text("utf-8")
        payload = json.loads(payload_text)
        self.assertEqual(
            payload,
            {"version": 1, "eui64": EUI64, "device_type": "light"},
        )
        self.assertNotIn("install_code", payload_text)

        svg_text = (self.output_dir / "label.svg").read_text("utf-8")
        self.assertIn("<svg", svg_text)
        self.assertNotIn(INSTALL_CODE, svg_text)

    def test_missing_token_fails_before_http_request(self) -> None:
        env = self.env.copy()
        env.pop("SB_MANUFACTURING_ACCESS_TOKEN")

        result = self.run_cli(env=env)

        self.assertNotEqual(result.returncode, 0)
        self.assert_secrets_hidden(result)
        self.assertEqual(self.cloud.requests, [])

    def test_factory_failure_does_not_echo_server_body(self) -> None:
        self.cloud.fail_factory = True

        result = self.run_cli()

        self.assertNotEqual(result.returncode, 0)
        self.assert_secrets_hidden(result)
        self.assertEqual(
            [request["path"] for request in self.cloud.requests],
            ["/api/provisioning/factory-devices"],
        )


class PowerShellManufacturingCliTests(
    _ManufacturingCliContract, unittest.TestCase
):
    script_path = POWERSHELL_SCRIPT

    @classmethod
    def setUpClass(cls) -> None:
        cls.powershell = shutil.which("powershell.exe") or shutil.which("pwsh")
        if cls.powershell is None:
            raise unittest.SkipTest("PowerShell runtime is not available")

    def build_command(self, output_dir: Path) -> list[str]:
        return [
            self.powershell,
            "-NoProfile",
            "-File",
            str(self.script_path),
            "-Eui64",
            EUI64,
            "-InstallCode",
            INSTALL_CODE,
            "-DeviceType",
            "light",
            "-Model",
            "EFR32MG12_LIGHT_KIT",
            "-OutputDirectory",
            str(output_dir),
        ]


class BashManufacturingCliTests(_ManufacturingCliContract, unittest.TestCase):
    script_path = BASH_SCRIPT

    @classmethod
    def setUpClass(cls) -> None:
        cls.bash = _find_working_bash()
        if cls.bash is None:
            raise unittest.SkipTest("Bash runtime is not available")

    def build_command(self, output_dir: Path) -> list[str]:
        return [
            self.bash,
            _bash_path(self.script_path),
            "--eui64",
            EUI64,
            "--install-code",
            INSTALL_CODE,
            "--device-type",
            "light",
            "--model",
            "EFR32MG12_LIGHT_KIT",
            "--output-directory",
            _bash_path(output_dir),
        ]


if __name__ == "__main__":
    unittest.main()
