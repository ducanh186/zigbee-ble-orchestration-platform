"""
Command lifecycle tracking for MQTT command requests.
"""

from __future__ import annotations

import threading
import time
from dataclasses import dataclass
from typing import Callable

from .models import COMMAND_STATUSES


TERMINAL_STATUSES = {"executed", "failed", "timeout"}
ALLOWED_TRANSITIONS = {
    None: {"accepted"},
    "accepted": {"queued", "failed"},
    "queued": {"sent", "failed"},
    "sent": {"executed", "failed", "timeout"},
    "executed": set(),
    "failed": set(),
    "timeout": set(),
}


@dataclass(frozen=True)
class PendingCommand:
    """Pending command metadata while waiting for a terminal adapter reply."""

    command_id: str
    device_id: str | None
    trace_id: str | None
    deadline_monotonic: float


class CommandLifecycleTracker:
    """Track transitions and emit timeout callbacks when commands expire."""

    def __init__(
        self,
        default_timeout_ms: int,
        on_timeout: Callable[[PendingCommand], None],
    ):
        self.default_timeout_ms = default_timeout_ms
        self.on_timeout = on_timeout
        self._states: dict[str, str] = {}
        self._pending: dict[str, PendingCommand] = {}
        self._lock = threading.Lock()
        self._running = False
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        self._running = True
        self._thread = threading.Thread(target=self._timeout_loop, daemon=True, name="command-timeouts")
        self._thread.start()

    def stop(self) -> None:
        self._running = False

    def transition(
        self,
        command_id: str,
        status: str,
        *,
        device_id: str | None = None,
        trace_id: str | None = None,
        timeout_ms: int | None = None,
    ) -> bool:
        """Move a command through the allowed lifecycle graph."""

        if status not in COMMAND_STATUSES:
            raise ValueError(f"Unsupported command status: {status}")

        with self._lock:
            current = self._states.get(command_id)
            if current == status:
                return False

            allowed = ALLOWED_TRANSITIONS[current]
            if status not in allowed:
                raise ValueError(f"Invalid lifecycle transition {current!r} -> {status!r}")

            self._states[command_id] = status

            if status == "sent":
                timeout_seconds = (timeout_ms or self.default_timeout_ms) / 1000.0
                self._pending[command_id] = PendingCommand(
                    command_id=command_id,
                    device_id=device_id,
                    trace_id=trace_id,
                    deadline_monotonic=time.monotonic() + timeout_seconds,
                )
            elif status in TERMINAL_STATUSES:
                self._pending.pop(command_id, None)

        return True

    def state_for(self, command_id: str) -> str | None:
        """Return the current lifecycle state for a command."""

        with self._lock:
            return self._states.get(command_id)

    def _timeout_loop(self) -> None:
        while self._running:
            expired: list[PendingCommand] = []
            now = time.monotonic()
            with self._lock:
                for command_id, pending in list(self._pending.items()):
                    if now >= pending.deadline_monotonic:
                        self._states[command_id] = "timeout"
                        self._pending.pop(command_id, None)
                        expired.append(pending)

            for pending in expired:
                self.on_timeout(pending)

            time.sleep(0.1)
