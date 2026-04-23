from pydantic import BaseModel


class MacRegistrationRequest(BaseModel):
    displayName: str


class MacResponse(BaseModel):
    macId: str
    displayName: str


class TunnelResponse(BaseModel):
    tunnelId: str
    tunnelToken: str
    hostname: str


class RevokeTunnelResponse(BaseModel):
    revoked: bool
