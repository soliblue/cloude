from pydantic import BaseModel


class MacRecord(BaseModel):
    mac_installation_id: str
    mac_secret_hash: str
    app_install_id: str | None
    display_name: str
    created_at: int
    last_seen_at: int


class TunnelRecord(BaseModel):
    mac_installation_id: str
    cloudflare_tunnel_id: str
    hostname: str
    dns_record_id: str
    status: str
    created_at: int
    last_heartbeat_at: int | None
