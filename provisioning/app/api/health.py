from fastapi import APIRouter

from app.schemas.common import HealthResponse


router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
def get_health():
    return HealthResponse(ok=True)
