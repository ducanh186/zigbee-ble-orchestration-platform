from __future__ import annotations

from pathlib import Path

from pydantic_settings import BaseSettings


_CLOUD_ENV_FILE = Path(__file__).resolve().parents[1] / ".env"


class Settings(BaseSettings):
    """Cloud backend configuration loaded from environment variables."""

    database_url: str = "postgresql+asyncpg://sb_user:sb_pass@localhost:5432/sb_cloud"
    mqtt_host: str = "localhost"
    mqtt_port: int = 1883
    mqtt_username: str = "client"
    mqtt_password: str = "client"
    tenant_id: str = "hust"
    site_id: str = "lab01"
    gateway_id: str = "gw-ubuntu-01"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    api_auth_token: str | None = None

    model_config = {"env_prefix": "SB_", "env_file": _CLOUD_ENV_FILE, "extra": "ignore"}


settings = Settings()
