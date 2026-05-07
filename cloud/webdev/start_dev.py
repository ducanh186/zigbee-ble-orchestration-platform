from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen


ROOT = Path(__file__).resolve().parents[2]
WEBDEV = ROOT / "cloud" / "webdev"
PYTHON = ROOT / ".venv" / "Scripts" / "python.exe"


def main() -> int:
    python = str(PYTHON if PYTHON.exists() else Path(sys.executable))
    env = os.environ.copy()
    env.setdefault("SB_DATABASE_URL", "sqlite+aiosqlite:///./cloud/dev.db")
    env.setdefault("SB_API_HOST", "127.0.0.1")
    env.setdefault("SB_API_PORT", "8000")

    print("Seeding cloud dev database...", flush=True)
    seed = subprocess.run(
        [python, "-m", "cloud.app.seed"],
        cwd=ROOT,
        env=env,
        check=False,
    )
    if seed.returncode != 0:
        return seed.returncode

    api_port = env["SB_API_PORT"]
    ui_port = os.environ.get("WEBDEV_PORT", "5173")
    api_url = f"http://127.0.0.1:{api_port}"
    ui_url = f"http://127.0.0.1:{ui_port}"

    api = None
    ui = None

    print(f"Cloud API: {api_url}", flush=True)
    print(f"Web UI:    {ui_url}", flush=True)
    print("Press Ctrl+C to stop both servers.", flush=True)

    try:
        while True:
            if api is None or api.poll() is not None:
                if api is not None:
                    print(f"Cloud API exited with code {api.returncode}; restarting...", flush=True)
                api = start_api(python, env, api_port)
                wait_for_api(api_url)

            if ui is None or ui.poll() is not None:
                if ui is not None:
                    print(f"Web UI exited with code {ui.returncode}; restarting...", flush=True)
                ui = start_ui(python, env, ui_port, api_url)

            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nStopping dev servers...")
        if api is not None:
            stop(api)
        if ui is not None:
            stop(ui)
        return 0


def start_api(python: str, env: dict[str, str], api_port: str) -> subprocess.Popen:
    print("Starting Cloud API...", flush=True)
    return subprocess.Popen(
        [
            python,
            "-m",
            "uvicorn",
            "cloud.app.main:app",
            "--host",
            "127.0.0.1",
            "--port",
            api_port,
        ],
        cwd=ROOT,
        env=env,
    )


def start_ui(
    python: str, env: dict[str, str], ui_port: str, api_url: str
) -> subprocess.Popen:
    print("Starting Web UI...", flush=True)
    return subprocess.Popen(
        [
            python,
            str(WEBDEV / "dev_server.py"),
            "--host",
            "127.0.0.1",
            "--port",
            ui_port,
            "--api-target",
            api_url,
        ],
        cwd=WEBDEV,
        env=env,
    )


def wait_for_api(api_url: str) -> None:
    deadline = time.time() + 20
    while time.time() < deadline:
        try:
            with urlopen(f"{api_url}/health", timeout=2) as response:
                if response.status == 200:
                    print("Cloud API is healthy.", flush=True)
                    return
        except URLError:
            pass
        time.sleep(0.5)
    print("Cloud API health check did not pass yet; continuing.", flush=True)


def stop(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    try:
        process.terminate()
        process.wait(timeout=5)
    except Exception:
        process.kill()


if __name__ == "__main__":
    raise SystemExit(main())
