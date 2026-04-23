import base64
import hashlib
import hmac
import secrets

from app.core.config import settings


def token(byte_count: int) -> str:
    return base64.urlsafe_b64encode(secrets.token_bytes(byte_count)).decode().rstrip("=")


def dns_label(length: int) -> str:
    return "".join(secrets.choice("abcdefghijklmnopqrstuvwxyz0123456789") for _ in range(length))


def secret_hash(value: str) -> str:
    token_secret = settings().provisioning_token_secret
    if token_secret:
        return hmac.new(token_secret.encode(), value.encode(), hashlib.sha256).hexdigest()
    return hashlib.sha256(value.encode()).hexdigest()
