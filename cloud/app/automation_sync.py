from __future__ import annotations

from cloud.app.models import Automation


def mark_sync_pending(rule: Automation, operation: str) -> None:
    """Record that Gateway sync is still awaiting a real acknowledgement."""
    rule.sync_status = "pending"
    rule.last_error = None
