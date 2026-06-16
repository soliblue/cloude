from fastapi import HTTPException, status

from app.db.connection import db
from app.models.records import MacRecord, TunnelRecord


def upsert_mac(mac_id: str, mac_secret_hash: str, display_name: str, now: int):
    with db() as conn:
        conn.execute(
            """
            insert into macs (mac_installation_id, mac_secret_hash, app_install_id, display_name, created_at, last_seen_at)
            values (?, ?, null, ?, ?, ?)
            on conflict(mac_installation_id) do update set
              display_name = excluded.display_name,
              last_seen_at = excluded.last_seen_at
            where macs.mac_secret_hash = excluded.mac_secret_hash
            """,
            (mac_id, mac_secret_hash, display_name, now, now),
        )


def mac(mac_id: str) -> MacRecord:
    with db() as conn:
        row = conn.execute(
            "select * from macs where mac_installation_id = ?",
            (mac_id,),
        ).fetchone()
    if row:
        return MacRecord(**dict(row))
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid mac credentials")


def active_tunnel(mac_id: str) -> TunnelRecord | None:
    with db() as conn:
        row = conn.execute(
            """
            select *
            from tunnels
            where mac_installation_id = ? and status = 'active'
            """,
            (mac_id,),
        ).fetchone()
    return TunnelRecord(**dict(row)) if row else None


def insert_tunnel(mac_id: str, tunnel_id: str, hostname: str, dns_record_id: str, created_at: int):
    with db() as conn:
        conn.execute(
            """
            insert into tunnels (mac_installation_id, cloudflare_tunnel_id, hostname, dns_record_id, status, created_at, last_heartbeat_at)
            values (?, ?, ?, ?, 'active', ?, null)
            on conflict(mac_installation_id) do update set
              cloudflare_tunnel_id = excluded.cloudflare_tunnel_id,
              hostname = excluded.hostname,
              dns_record_id = excluded.dns_record_id,
              status = 'active',
              created_at = excluded.created_at,
              last_heartbeat_at = null
            """,
            (mac_id, tunnel_id, hostname, dns_record_id, created_at),
        )


def mark_tunnel_revoked(mac_id: str):
    with db() as conn:
        conn.execute(
            "update tunnels set status = 'revoked' where mac_installation_id = ?",
            (mac_id,),
        )


def mark_heartbeat(mac_id: str, now: int):
    with db() as conn:
        conn.execute(
            "update macs set last_seen_at = ? where mac_installation_id = ?",
            (now, mac_id),
        )
        conn.execute(
            """
            update tunnels
            set last_heartbeat_at = ?
            where mac_installation_id = ? and status = 'active'
            """,
            (now, mac_id),
        )
