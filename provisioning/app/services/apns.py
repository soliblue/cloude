import base64
import json
import time

import httpx
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

from app.core.config import settings


def configured() -> bool:
    config = settings()
    return bool(config.apns_key_id and config.apns_team_id and config.apns_auth_key_content and config.apns_topic)


def topic() -> str:
    return settings().apns_topic


def notification_payload(title: str, body: str, session_id: str | None, schedule_id: str | None = None, run_id: str | None = None) -> dict:
    payload = {"aps": {"alert": {"title": title, "body": body}, "sound": "default"}}
    if session_id:
        payload["sessionId"] = session_id
    if schedule_id and run_id:
        payload["scheduleId"] = schedule_id
        payload["runId"] = run_id
    return payload


def payload_size(title: str, body: str, session_id: str | None, schedule_id: str | None = None, run_id: str | None = None) -> int:
    return len(json.dumps(notification_payload(title, body, session_id, schedule_id, run_id), separators=(",", ":")).encode())


def _base64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _jwt() -> str:
    config = settings()
    header = _base64url(json.dumps({"alg": "ES256", "kid": config.apns_key_id}, separators=(",", ":")).encode())
    claims = _base64url(json.dumps({"iss": config.apns_team_id, "iat": int(time.time())}, separators=(",", ":")).encode())
    key = load_pem_private_key(config.apns_auth_key_content.encode(), password=None)
    signature = key.sign(f"{header}.{claims}".encode(), ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(signature)
    return f"{header}.{claims}.{_base64url(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


async def send(device: dict, title: str, body: str, session_id: str | None, schedule_id: str | None = None, run_id: str | None = None):
    config = settings()
    host = "https://api.sandbox.push.apple.com" if config.apns_use_sandbox or device["environment"] == "sandbox" else "https://api.push.apple.com"
    payload = notification_payload(title, body, session_id, schedule_id, run_id)
    async with httpx.AsyncClient(http2=True, timeout=15) as client:
        response = await client.post(
            f"{host}/3/device/{device['token']}",
            headers={"authorization": f"bearer {_jwt()}", "apns-topic": config.apns_topic, "apns-push-type": "alert", "apns-priority": "10"},
            json=payload,
        )
    return response.status_code, response.json() if response.content else {}
