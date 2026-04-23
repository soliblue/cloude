from pydantic import BaseModel


class PairingStartRequest(BaseModel):
    macInstallationId: str
    macSecret: str
    displayName: str


class PairingPayload(BaseModel):
    backendURL: str
    pairingId: str
    pairingSecret: str


class PairingSessionResponse(BaseModel):
    pairingId: str
    pairingSecret: str
    expiresAt: int
    payload: PairingPayload


class PairingCompleteRequest(BaseModel):
    appInstallId: str
    pairingSecret: str


class PairingCompleteResponse(BaseModel):
    macInstallationId: str
    displayName: str
    hostname: str | None
