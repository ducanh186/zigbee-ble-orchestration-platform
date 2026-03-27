"""
Runtime configuration for the MQTT <-> IPC bridge.
"""

from __future__ import annotations

from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENV_FILE = PACKAGE_ROOT / ".env"


class BridgeSettings(BaseSettings):
    """Configuration loaded from environment variables and gateway/.env."""

    sb_tenant_id: str = Field(default="hust", validation_alias="SB_TENANT_ID")
    sb_site_id: str = Field(default="lab01", validation_alias="SB_SITE_ID")
    sb_gateway_id: str = Field(default="gw-ubuntu-01", validation_alias="SB_GATEWAY_ID")

    sb_mqtt_host: str = Field(default="localhost", validation_alias="SB_MQTT_HOST")
    sb_mqtt_port: int = Field(default=1883, validation_alias="SB_MQTT_PORT")
    sb_mqtt_username: str = Field(default="", validation_alias="SB_MQTT_USERNAME")
    sb_mqtt_password: str = Field(default="", validation_alias="SB_MQTT_PASSWORD")
    sb_mqtt_keepalive: int = Field(default=60, validation_alias="SB_MQTT_KEEPALIVE")
    sb_mqtt_tls_enabled: bool = Field(default=False, validation_alias="SB_MQTT_TLS_ENABLED")
    sb_mqtt_tls_ca_cert: str = Field(default="", validation_alias="SB_MQTT_TLS_CA_CERT")
    sb_mqtt_tls_insecure: bool = Field(default=False, validation_alias="SB_MQTT_TLS_INSECURE")

    sb_ipc_socket_path: str = Field(default="/tmp/sb-gateway.sock", validation_alias="SB_IPC_SOCKET_PATH")
    sb_ota_dir: str = Field(default="./ota-files", validation_alias="SB_OTA_DIR")
    sb_command_timeout_ms: int = Field(default=5000, validation_alias="SB_COMMAND_TIMEOUT_MS")

    sb_log_level: str = Field(default="INFO", validation_alias="SB_LOG_LEVEL")
    sb_log_file: str = Field(default="", validation_alias="SB_LOG_FILE")

    model_config = SettingsConfigDict(
        case_sensitive=False,
        extra="ignore",
    )

    @field_validator("sb_mqtt_port")
    @classmethod
    def validate_port(cls, value: int) -> int:
        if not 1 <= value <= 65535:
            raise ValueError("SB_MQTT_PORT must be between 1 and 65535")
        return value

    @field_validator("sb_mqtt_keepalive", "sb_command_timeout_ms")
    @classmethod
    def validate_positive_int(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("Value must be positive")
        return value

    @field_validator("sb_log_level")
    @classmethod
    def validate_log_level(cls, value: str) -> str:
        allowed = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}
        upper = value.upper()
        if upper not in allowed:
            raise ValueError(f"SB_LOG_LEVEL must be one of {sorted(allowed)}")
        return upper

    @property
    def tenant_id(self) -> str:
        return self.sb_tenant_id

    @property
    def site_id(self) -> str:
        return self.sb_site_id

    @property
    def gateway_id(self) -> str:
        return self.sb_gateway_id

    @property
    def mqtt_host(self) -> str:
        return self.sb_mqtt_host

    @property
    def mqtt_port(self) -> int:
        return self.sb_mqtt_port

    @property
    def mqtt_keepalive(self) -> int:
        return self.sb_mqtt_keepalive

    @property
    def mqtt_username(self) -> str:
        return self.sb_mqtt_username

    @property
    def mqtt_password(self) -> str:
        return self.sb_mqtt_password

    @property
    def mqtt_auth_enabled(self) -> bool:
        return bool(self.mqtt_username and self.mqtt_password)

    @property
    def mqtt_tls_enabled(self) -> bool:
        return self.sb_mqtt_tls_enabled

    @property
    def mqtt_tls_ca_cert(self) -> str:
        return self.sb_mqtt_tls_ca_cert

    @property
    def mqtt_tls_insecure(self) -> bool:
        return self.sb_mqtt_tls_insecure

    @property
    def ipc_socket_path(self) -> Path:
        return Path(self.sb_ipc_socket_path)

    @property
    def ota_dir(self) -> Path:
        return Path(self.sb_ota_dir)

    @property
    def command_timeout_ms(self) -> int:
        return self.sb_command_timeout_ms

    @property
    def log_level(self) -> str:
        return self.sb_log_level

    @property
    def log_file(self) -> str:
        return self.sb_log_file


def load_settings(env_file: str | None = None) -> BridgeSettings:
    """Load validated settings from gateway/.env by default."""

    selected_env_file = Path(env_file) if env_file else DEFAULT_ENV_FILE
    kwargs = {}
    if selected_env_file.exists():
        kwargs["_env_file"] = selected_env_file
    return BridgeSettings(**kwargs)
