import time
import re

from fastapi import APIRouter, Depends, Header, HTTPException, status

from app.core.rate_limit import limit
from app.core.security import verify_mac
from app.db import queries
from app.schemas.push import PushDeviceDeleteResponse, PushDeviceRequest, PushDeviceResponse
from app.services import apns


router = APIRouter(prefix="/macs/{mac_id}/push-devices", tags=["push"])
notifications_router = APIRouter(prefix="/macs/{mac_id}", tags=["push"])


@router.put(
    "/{device_id}",
    response_model=PushDeviceResponse,
    dependencies=[Depends(limit("push-device-put", 60, 3600))],
)
def put_push_device(mac_id: str, device_id: str, request: PushDeviceRequest, x_mac_secret: str = Header(alias="X-Mac-Secret")):
    verify_mac(mac_id, x_mac_secret)
    bundle_id = request.appBundleId or request.bundleId or "soli.Cloude"
    if bundle_id != apns.topic():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="unsupported app bundle")
    queries.upsert_push_device(
        mac_id=mac_id,
        device_id=device_id,
        token=request.token,
        environment=request.environment,
        app_bundle_id=bundle_id,
        now=int(time.time()),
    )
    return PushDeviceResponse(registered=True)


@router.delete(
    "/{device_id}",
    response_model=PushDeviceDeleteResponse,
    dependencies=[Depends(limit("push-device-delete", 60, 3600))],
)
def delete_push_device(mac_id: str, device_id: str, x_mac_secret: str = Header(alias="X-Mac-Secret")):
    verify_mac(mac_id, x_mac_secret)
    return PushDeviceDeleteResponse(revoked=queries.delete_push_device(mac_id, device_id))


@notifications_router.post("/notifications")
async def send_notification(
    mac_id: str,
    request: dict,
    x_mac_secret: str = Header(alias="X-Mac-Secret"),
):
    verify_mac(mac_id, x_mac_secret)
    if not apns.configured():
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="push delivery is not configured")
    event_id = request.get("eventId")
    title = request.get("title")
    body = request.get("body")
    if not all(isinstance(value, str) and value for value in (event_id, title, body)):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="eventId, title and body are required")
    if any(len(value.encode("utf-8")) > limit for value, limit in ((event_id, 256), (title, 512), (body, 2048))):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="notification payload is too large")
    session_id = request.get("sessionId") if isinstance(request.get("sessionId"), str) else None
    if session_id and len(session_id.encode("utf-8")) > 256:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="sessionId is too large")
    route = {}
    if "scheduleId" in request or "runId" in request:
        if not all(isinstance(request.get(key), str) and re.fullmatch(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", request[key]) for key in ("sessionId", "scheduleId", "runId")):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="scheduled notifications require valid sessionId, scheduleId and runId")
        route = {"schedule_id": request["scheduleId"].lower(), "run_id": request["runId"].lower()}
    if apns.payload_size(title, body, session_id, **route) > 4096:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="notification payload is too large")
    claim, owner = queries.claim_notification(mac_id, event_id, int(time.time()))
    if claim == "delivered":
        return {"delivered": True, "duplicate": True}
    if claim == "busy":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="notification delivery in progress")
    failures = []
    delivered = queries.delivered_devices(mac_id, event_id)
    for device in queries.push_devices(mac_id):
        if device["device_id"] in delivered:
            continue
        if not queries.renew_notification(mac_id, event_id, owner, int(time.time())):
            failures.append(409)
            break
        try:
            response_status, response_body = await apns.send(device, title, body, session_id, **route)
            if response_status == 410 or response_body.get("reason") == "Unregistered":
                queries.delete_push_token(mac_id, device["token"])
            elif response_status < 200 or response_status >= 300:
                failures.append(response_status)
            else:
                if not queries.mark_device_delivered(mac_id, event_id, owner, device["device_id"], int(time.time())):
                    failures.append(409)
                    break
        except Exception:
            failures.append(503)
    if failures:
        queries.forget_notification(mac_id, event_id, owner)
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="push delivery failed")
    if not queries.complete_notification(mac_id, event_id, owner, int(time.time())):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="notification delivery lease expired")
    return {"delivered": True}
