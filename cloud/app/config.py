from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Cloud backend configuration loaded from environment variables."""

    database_url: str = "sqlite:///./cloud.db"
    mqtt_host: str = "localhost"
    mqtt_port: int = 1883
    mqtt_username: str = "client"
    mqtt_password: str = "client"
    tenant_id: str = "hust"
    site_id: str = "lab01"
    gateway_id: str = "gw-ubuntu-01"
    api_host: str = "0.0.0.0"
    api_port: int = 8000

    model_config = {"env_prefix": "SB_", "env_file": ".env", "extra": "ignore"}


settings = Settings()
