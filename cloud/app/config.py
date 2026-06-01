from __future__ import annotations

import os

from pydantic import Field
from pydantic_settings import BaseSettings


def _auth_token_secret_default() -> str:
    return os.getenv("SB_JWT_SECRET", "dev-only-change-me")


class Settings(BaseSettings):
    """Cloud backend configuration loaded from environment variables."""

    database_url: str = "postgresql+asyncpg://sb_user:sb_pass@localhost:5432/sb_cloud"
    mqtt_host: str = "localhost"
    mqtt_port: int = 1883
    mqtt_username: str = "client"
    mqtt_password: str = "client"
    mqtt_tls_enabled: bool = False
    mqtt_mtls_enabled: bool = False
    mqtt_ca_cert_path: str | None = None
    mqtt_client_cert_path: str | None = None
    mqtt_client_key_path: str | None = None
    tenant_id: str = "hust"
    site_id: str = "lab01"
    gateway_id: str = "gw-ubuntu-01"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    # How long (seconds) a device may go without a reported/event/registry
    # before the offline reaper marks `is_online=False`. Devices that have
    # never reported (`last_seen_at IS NULL`) are also marked offline so
    # seed rows and probes don't masquerade as live hardware.
    device_offline_after_seconds: int = 300
    # How often the reaper task wakes up to scan for stale devices.
    device_offline_scan_interval_seconds: int = 60
    auth_token_secret: str = Field(default_factory=_auth_token_secret_default)
    auth_token_ttl_seconds: int = 8 * 60 * 60

    model_config = {"env_prefix": "SB_", "env_file": ".env", "extra": "ignore"}


settings = Settings()
