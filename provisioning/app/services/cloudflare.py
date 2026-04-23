import httpx
from fastapi import HTTPException, status

from app.core.config import settings
from app.core.secrets import dns_label


CLOUDFLARE_API = "https://api.cloudflare.com/client/v4"


def create_tunnel(name: str) -> dict:
    return request_cloudflare("post", f"/accounts/{settings().cloudflare_account_id}/cfd_tunnel", {"name": name, "config_src": "cloudflare"})["result"]


def configure_tunnel(tunnel_id: str, tunnel_hostname: str) -> dict:
    return request_cloudflare(
        "put",
        f"/accounts/{settings().cloudflare_account_id}/cfd_tunnel/{tunnel_id}/configurations",
        {
            "config": {
                "ingress": [
                    {"hostname": tunnel_hostname, "service": settings().tunnel_origin_service},
                    {"service": "http_status:404"},
                ]
            }
        },
    )


def tunnel_token(tunnel_id: str) -> str:
    return request_cloudflare("get", f"/accounts/{settings().cloudflare_account_id}/cfd_tunnel/{tunnel_id}/token")["result"]


def create_dns_record(record_hostname: str, target: str) -> str:
    return request_cloudflare(
        "post",
        f"/zones/{settings().cloudflare_zone_id}/dns_records",
        {"type": "CNAME", "name": record_hostname, "content": target, "proxied": True},
    )["result"]["id"]


def delete_dns_record(dns_record_id: str) -> dict:
    return request_cloudflare("delete", f"/zones/{settings().cloudflare_zone_id}/dns_records/{dns_record_id}")


def delete_tunnel(tunnel_id: str) -> dict:
    return request_cloudflare("delete", f"/accounts/{settings().cloudflare_account_id}/cfd_tunnel/{tunnel_id}")


def hostname() -> str:
    return f"{dns_label(10)}-{settings().tunnel_host_label_suffix}.{settings().tunnel_host_suffix}"


def request_cloudflare(method: str, path: str, body: dict | None = None) -> dict:
    if settings().cloudflare_account_id and settings().cloudflare_zone_id and settings().cloudflare_api_token:
        response = httpx.request(
            method,
            f"{CLOUDFLARE_API}{path}",
            headers={
                "Authorization": f"Bearer {settings().cloudflare_api_token}",
                "Content-Type": "application/json",
            },
            json=body,
            timeout=30,
        )
        data = response.json()
        if response.is_success and data.get("success"):
            return data
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail={"cloudflare": data})
    raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="cloudflare env missing")
