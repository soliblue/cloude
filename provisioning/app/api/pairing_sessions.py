import secrets
import time

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import settings
from app.core.rate_limit import limit
from app.core.secrets import secret_hash, token
from app.db import queries
from app.schemas.pairing_sessions import (
    PairingCompleteRequest,
    PairingCompleteResponse,
    PairingPayload,
    PairingSessionResponse,
    PairingStartRequest,
)


router = APIRouter(prefix="/pairing-sessions", tags=["pairing sessions"])


@router.post(
    "",
    response_model=PairingSessionResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(limit("pairing-start", settings().rate_limit_register_per_hour, 3600))],
)
def create_pairing_session(request: PairingStartRequest):
    pairing_id = token(18)
    pairing_secret = token(32)
    now = int(time.time())
    expires_at = now + settings().pairing_ttl_seconds
    queries.upsert_mac(
        mac_id=request.macInstallationId,
        mac_secret_hash=secret_hash(request.macSecret),
        display_name=request.displayName,
        now=now,
    )
    queries.insert_pairing_session(
        pairing_id=pairing_id,
        pairing_secret_hash=secret_hash(pairing_secret),
        mac_id=request.macInstallationId,
        expires_at=expires_at,
    )
    return PairingSessionResponse(
        pairingId=pairing_id,
        pairingSecret=pairing_secret,
        expiresAt=expires_at,
        payload=PairingPayload(
            backendURL=settings().public_base_url,
            pairingId=pairing_id,
            pairingSecret=pairing_secret,
        ),
    )


@router.post(
    "/{pairing_id}/completion",
    response_model=PairingCompleteResponse,
    dependencies=[Depends(limit("pairing-complete", settings().rate_limit_auth_attempts_per_minute, 60))],
)
def complete_pairing_session(pairing_id: str, request: PairingCompleteRequest):
    now = int(time.time())
    pairing = queries.pairing_session(pairing_id)
    if pairing and pairing.consumed_at is None and pairing.expires_at > now and secrets.compare_digest(pairing.pairing_secret_hash, secret_hash(request.pairingSecret)):
        mac = queries.mac(pairing.mac_installation_id)
        queries.complete_pairing(app_install_id=request.appInstallId, mac_id=pairing.mac_installation_id, pairing_id=pairing_id, now=now)
        tunnel = queries.active_tunnel(pairing.mac_installation_id)
        return PairingCompleteResponse(
            macInstallationId=mac.mac_installation_id,
            displayName=mac.display_name,
            hostname=tunnel.hostname if tunnel else None,
        )
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid pairing")
