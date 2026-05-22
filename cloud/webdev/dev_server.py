from __future__ import annotations

import argparse
import json
import mimetypes
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
DEFAULT_PORT = int(os.environ.get("PORT", "5173"))
DEFAULT_API_TARGET = os.environ.get("API_TARGET", "http://127.0.0.1:8000").rstrip("/")


class WebdevHandler(BaseHTTPRequestHandler):
    api_target = DEFAULT_API_TARGET

    def do_GET(self) -> None:
        self.route()

    def do_HEAD(self) -> None:
        self.route(head_only=True)

    def do_POST(self) -> None:
        self.route()

    def do_PUT(self) -> None:
        self.route()

    def do_DELETE(self) -> None:
        self.route()

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("access-control-allow-origin", "*")
        self.send_header("access-control-allow-methods", "GET,POST,PUT,DELETE,OPTIONS")
        self.send_header("access-control-allow-headers", "content-type,authorization")
        self.end_headers()

    def route(self, head_only: bool = False) -> None:
        parsed = urlsplit(self.path)
        if parsed.path == "/health" or parsed.path.startswith("/api/"):
            self.proxy_api(head_only=head_only)
            return
        self.serve_static(parsed.path, head_only=head_only)

    def serve_static(self, path: str, head_only: bool = False) -> None:
        relative = path.lstrip("/") or "index.html"
        if relative.startswith("static/"):
            relative = relative[len("static/"):]
        candidate = (ROOT / relative).resolve()
        if ROOT not in candidate.parents and candidate != ROOT:
            self.send_error(403)
            return
        if candidate.is_dir():
            candidate = candidate / "index.html"
        if not candidate.exists():
            candidate = ROOT / "index.html"

        content_type = mimetypes.guess_type(candidate.name)[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("content-type", content_type)
        self.send_header("cache-control", "no-store")
        self.send_header("content-length", str(candidate.stat().st_size))
        self.end_headers()
        if not head_only:
            self.wfile.write(candidate.read_bytes())

    def proxy_api(self, head_only: bool = False) -> None:
        target = f"{self.api_target}{self.path}"
        body = None
        content_length = self.headers.get("content-length")
        if content_length:
            body = self.rfile.read(int(content_length))

        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in {"host", "content-length", "connection"}
        }
        request = Request(target, data=body, headers=headers, method=self.command)

        try:
            with urlopen(request, timeout=20) as response:
                payload = response.read()
                self.send_response(response.status)
                for key, value in response.headers.items():
                    if key.lower() not in {"connection", "transfer-encoding"}:
                        self.send_header(key, value)
                self.send_header("access-control-allow-origin", "*")
                self.end_headers()
                if not head_only:
                    self.wfile.write(payload)
        except HTTPError as error:
            payload = error.read()
            self.send_response(error.code)
            for key, value in error.headers.items():
                if key.lower() not in {"connection", "transfer-encoding"}:
                    self.send_header(key, value)
            self.send_header("access-control-allow-origin", "*")
            self.end_headers()
            if not head_only:
                self.wfile.write(payload)
        except URLError as error:
            self.send_json(502, {"detail": f"API proxy failed: {error.reason}"})

    def send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args) -> None:
        print(f"{self.address_string()} - {fmt % args}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=os.environ.get("HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--api-target", default=DEFAULT_API_TARGET)
    args = parser.parse_args()

    WebdevHandler.api_target = args.api_target.rstrip("/")
    server = ThreadingHTTPServer((args.host, args.port), WebdevHandler)
    print(f"webdev listening on http://{args.host}:{args.port}")
    print(f"proxying API to {WebdevHandler.api_target}")
    server.serve_forever()


if __name__ == "__main__":
    main()
