import secrets
import threading
import time
from contextlib import suppress

from fastapi import APIRouter, Depends, Header, HTTPException, status

from app.core.config import settings
from app.core.rate_limit import limit
from app.core.secrets import secret_hash, token
from app.core.security import verify_mac
from app.db import queries
from app.schemas.common import HealthResponse
from app.schemas.macs import MacRegistrationRequest, MacResponse, RevokeTunnelResponse, TunnelResponse
from app.services import cloudflare


router = APIRouter(prefix="/macs/{mac_id}", tags=["macs"])
provision_lock = threading.Lock()


@router.put(
    "",
    response_model=MacResponse,
    dependencies=[Depends(limit("mac-put", settings().rate_limit_register_per_hour, 3600))],
)
def put_mac(mac_id: str, request: MacRegistrationRequest, x_mac_secret: str = Header(alias="X-Mac-Secret")):
    presented = secret_hash(x_mac_secret)
    queries.upsert_mac(
        mac_id=mac_id,
        mac_secret_hash=presented,
        display_name=request.displayName,
        now=int(time.time()),
    )
    stored = queries.mac(mac_id)
    if not secrets.compare_digest(stored.mac_secret_hash, presented):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid mac credentials")
    return MacResponse(macId=mac_id, displayName=request.displayName)


@router.put(
    "/tunnel",
    response_model=TunnelResponse,
    dependencies=[Depends(limit("tunnel-put", settings().rate_limit_tunnel_mutations_per_hour, 3600))],
)
def put_tunnel(mac_id: str, x_mac_secret: str = Header(alias="X-Mac-Secret")):
    verify_mac(mac_id, x_mac_secret)
    with provision_lock:
        existing = queries.active_tunnel(mac_id)
        if existing:
            return TunnelResponse(
                tunnelId=existing.cloudflare_tunnel_id,
                tunnelToken=cloudflare.tunnel_token(existing.cloudflare_tunnel_id),
                hostname=existing.hostname,
            )

        created = cloudflare.create_tunnel(f"remotecc-{mac_id}-{token(6)}")
        tunnel_id = created["id"]
        hostname = cloudflare.hostname()
        dns_record_id = None
        try:
            dns_record_id = cloudflare.create_dns_record(hostname, f"{tunnel_id}.cfargotunnel.com")
            cloudflare.configure_tunnel(tunnel_id, hostname)
        except Exception:
            if dns_record_id:
                with suppress(Exception):
                    cloudflare.delete_dns_record(dns_record_id)
            with suppress(Exception):
                cloudflare.delete_tunnel(tunnel_id)
            raise
        queries.insert_tunnel(
            mac_id=mac_id,
            tunnel_id=tunnel_id,
            hostname=hostname,
            dns_record_id=dns_record_id,
            created_at=int(time.time()),
        )
        return TunnelResponse(tunnelId=tunnel_id, tunnelToken=cloudflare.tunnel_token(tunnel_id), hostname=hostname)


@router.delete(
    "/tunnel",
    response_model=RevokeTunnelResponse,
    dependencies=[Depends(limit("tunnel-delete", settings().rate_limit_tunnel_mutations_per_hour, 3600))],
)
def delete_tunnel(mac_id: str, x_mac_secret: str = Header(alias="X-Mac-Secret")):
    verify_mac(mac_id, x_mac_secret)
    with provision_lock:
        tunnel = queries.active_tunnel(mac_id)
        if tunnel:
            cloudflare.delete_dns_record(tunnel.dns_record_id)
            cloudflare.delete_tunnel(tunnel.cloudflare_tunnel_id)
            queries.mark_tunnel_revoked(mac_id)
            return RevokeTunnelResponse(revoked=True)
        return RevokeTunnelResponse(revoked=False)


@router.put(
    "/heartbeat",
    response_model=HealthResponse,
    dependencies=[Depends(limit("heartbeat", settings().rate_limit_heartbeat_per_minute, 60))],
)
def put_heartbeat(mac_id: str, x_mac_secret: str = Header(alias="X-Mac-Secret")):
    verify_mac(mac_id, x_mac_secret)
    queries.mark_heartbeat(mac_id, int(time.time()))
    active = queries.active_tunnel(mac_id)
    return HealthResponse(ok=True, tunnelStatus="active" if active else "none")
