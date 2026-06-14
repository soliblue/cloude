import json
import sys
import time
import base64
import os
import requests
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
from cryptography.hazmat.backends import default_backend

ORPHAN_NAME = "Created via API"
API = "https://api.appstoreconnect.apple.com/v1/certificates"


def token():
    key = serialization.load_pem_private_key(
        os.environ["APP_STORE_CONNECT_API_KEY_CONTENT"].encode(),
        password=None,
        backend=default_backend(),
    )
    key_id = os.environ["APP_STORE_CONNECT_API_KEY_ID"]
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {
        "iss": os.environ["APP_STORE_CONNECT_API_ISSUER_ID"],
        "aud": "appstoreconnect-v1",
        "sub": key_id,
        "iat": now,
        "exp": now + 1200,
    }
    segments = [
        base64.urlsafe_b64encode(json.dumps(part).encode()).rstrip(b"=").decode()
        for part in (header, payload)
    ]
    message = ".".join(segments)
    r, s = decode_dss_signature(key.sign(message.encode(), ec.ECDSA(hashes.SHA256())))
    signature = r.to_bytes(32, "big") + s.to_bytes(32, "big")
    return f"{message}.{base64.urlsafe_b64encode(signature).rstrip(b'=').decode()}"


def headers():
    return {"Authorization": f"Bearer {token()}"}


def orphan_ids():
    response = requests.get(
        f"{API}?filter[certificateType]=IOS_DEVELOPMENT&limit=200", headers=headers()
    )
    response.raise_for_status()
    return {
        cert["id"]
        for cert in response.json().get("data", [])
        if cert["attributes"].get("name") == ORPHAN_NAME
    }


def revoke(ids):
    head = headers()
    for cert_id in ids:
        resp = requests.delete(f"{API}/{cert_id}", headers=head)
        print(f"  revoke {cert_id}: {resp.status_code}")
    print(f"Revoked {len(ids)} '{ORPHAN_NAME}' development certificate(s).")


command = sys.argv[1]

if command == "snapshot":
    before = orphan_ids()
    with open(sys.argv[2], "w") as f:
        json.dump(sorted(before), f)
    print(f"Snapshotted {len(before)} existing '{ORPHAN_NAME}' dev cert(s) before build.")

if command == "revoke-new":
    with open(sys.argv[2]) as f:
        before = set(json.load(f))
    revoke(orphan_ids() - before)

if command == "revoke-all":
    revoke(orphan_ids())
