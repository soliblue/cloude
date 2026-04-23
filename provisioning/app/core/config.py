from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    cloudflare_account_id: str = ""
    cloudflare_zone_id: str = ""
    cloudflare_api_token: str = ""
    database_path: Path = Path("provisioning.db")
    pairing_ttl_seconds: int = 300
    public_base_url: str = "https://remotecc.soli.blue"
    provisioning_token_secret: str = ""
    rate_limit_auth_attempts_per_minute: int = 20
    rate_limit_heartbeat_per_minute: int = 120
    rate_limit_register_per_hour: int = 20
    rate_limit_tunnel_mutations_per_hour: int = 30
    tunnel_host_suffix: str = "soli.blue"
    tunnel_host_label_suffix: str = "remotecc"
    tunnel_origin_service: str = "http://localhost:8765"

    model_config = SettingsConfigDict(env_file=("../.env", ".env"), extra="ignore")


@lru_cache
def settings() -> Settings:
    return Settings()
