from typing import Literal

from pydantic import BaseModel


class PushDeviceRequest(BaseModel):
    deviceId: str
    token: str
    environment: Literal["sandbox", "production"]
    appBundleId: str | None = None
    bundleId: str | None = None


class PushDeviceResponse(BaseModel):
    registered: bool


class PushDeviceDeleteResponse(BaseModel):
    revoked: bool
