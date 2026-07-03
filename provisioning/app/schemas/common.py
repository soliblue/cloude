from pydantic import BaseModel


class HealthResponse(BaseModel):
    ok: bool
    tunnelStatus: str | None = None
