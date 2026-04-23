import secrets

from fastapi import HTTPException, status

from app.core.secrets import secret_hash
from app.db import queries


def verify_mac(mac_id: str, mac_secret: str):
    mac = queries.mac(mac_id)
    if secrets.compare_digest(mac.mac_secret_hash, secret_hash(mac_secret)):
        return
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid mac credentials")
