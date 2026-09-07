from pydantic import BaseModel


class PushDeviceRecord(BaseModel):
    mac_installation_id: str
    device_id: str
    token: str
    environment: str
    app_bundle_id: str
    created_at: int
    last_seen_at: int
