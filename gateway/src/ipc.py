"""
Unix domain socket NDJSON transport for the local Z3Gateway adapter boundary.
"""

from __future__ import annotations

import json
import logging
import os
import socket
import threading
from pathlib import Path
from typing import Callable

from .models import IPCRecord


logger = logging.getLogger(__name__)


def encode_record(record: IPCRecord) -> str:
    """Encode an IPC record as NDJSON."""

    return record.model_dump_json(exclude_none=True) + "\n"


def decode_record(line: str) -> IPCRecord:
    """Decode a single NDJSON line into an IPC record."""

    return IPCRecord.model_validate_json(line)


class UnixSocketIPCServer:
    """Single-client AF_UNIX server with full-duplex NDJSON messaging."""

    def __init__(
        self,
        socket_path: Path,
        on_record: Callable[[IPCRecord], None],
        on_connection_change: Callable[[bool], None] | None = None,
    ):
        self.socket_path = socket_path
        self.on_record = on_record
        self.on_connection_change = on_connection_change

        self._server_socket: socket.socket | None = None
        self._client_socket: socket.socket | None = None
        self._running = False
        self._accept_thread: threading.Thread | None = None
        self._reader_thread: threading.Thread | None = None
        self._lock = threading.Lock()

    @property
    def is_connected(self) -> bool:
        with self._lock:
            return self._client_socket is not None

    def start(self) -> None:
        """Start accepting local adapter connections."""

        if os.name != "posix" or not hasattr(socket, "AF_UNIX"):
            raise RuntimeError("The IPC server requires a POSIX runtime with AF_UNIX support")

        self.socket_path.parent.mkdir(parents=True, exist_ok=True)
        if self.socket_path.exists():
            self.socket_path.unlink()

        self._server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._server_socket.settimeout(0.5)
        self._server_socket.bind(str(self.socket_path))
        self._server_socket.listen(1)
        self._running = True

        self._accept_thread = threading.Thread(target=self._accept_loop, daemon=True, name="ipc-accept")
        self._accept_thread.start()

    def stop(self) -> None:
        """Stop the server and clean up the socket file."""

        self._running = False
        with self._lock:
            client_socket = self._client_socket
            server_socket = self._server_socket
            self._client_socket = None
            self._server_socket = None

        for sock in (client_socket, server_socket):
            if sock is not None:
                try:
                    sock.close()
                except OSError:
                    pass

        if self.socket_path.exists():
            try:
                self.socket_path.unlink()
            except OSError:
                logger.warning("Unable to remove stale socket path %s", self.socket_path)

    def send(self, record: IPCRecord) -> bool:
        """Send an IPC record to the connected adapter."""

        payload = encode_record(record).encode("utf-8")
        with self._lock:
            client_socket = self._client_socket
        if client_socket is None:
            return False

        try:
            client_socket.sendall(payload)
            return True
        except OSError:
            logger.warning("Failed to send IPC record; dropping adapter connection")
            self._drop_client()
            return False

    def _accept_loop(self) -> None:
        while self._running and self._server_socket is not None:
            try:
                client_socket, _ = self._server_socket.accept()
            except TimeoutError:
                continue
            except OSError:
                if self._running:
                    logger.exception("IPC accept loop failed")
                return

            client_socket.settimeout(0.5)
            self._replace_client(client_socket)

    def _replace_client(self, client_socket: socket.socket) -> None:
        with self._lock:
            previous = self._client_socket
            self._client_socket = client_socket

        if previous is not None:
            try:
                previous.close()
            except OSError:
                pass

        if self.on_connection_change:
            self.on_connection_change(True)

        self._reader_thread = threading.Thread(
            target=self._reader_loop,
            args=(client_socket,),
            daemon=True,
            name="ipc-reader",
        )
        self._reader_thread.start()

    def _reader_loop(self, client_socket: socket.socket) -> None:
        buffer = ""
        try:
            while self._running:
                try:
                    chunk = client_socket.recv(4096)
                except TimeoutError:
                    continue
                if not chunk:
                    break

                buffer += chunk.decode("utf-8")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        record = decode_record(line)
                    except (json.JSONDecodeError, ValueError):
                        logger.exception("Invalid IPC line received: %s", line)
                        continue
                    self.on_record(record)
        except OSError:
            logger.warning("IPC reader loop stopped due to socket error")
        finally:
            self._drop_client(client_socket)

    def _drop_client(self, client_socket: socket.socket | None = None) -> None:
        notify = False
        with self._lock:
            current = self._client_socket
            if current is not None and (client_socket is None or current is client_socket):
                self._client_socket = None
                notify = True
                try:
                    current.close()
                except OSError:
                    pass

        if notify and self.on_connection_change:
            self.on_connection_change(False)
