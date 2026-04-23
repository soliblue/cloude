from fastapi import HTTPException, status

from app.db.connection import db
from app.models.records import MacRecord, PairingSessionRecord, TunnelRecord


def upsert_mac(mac_id: str, mac_secret_hash: str, display_name: str, now: int):
    with db() as conn:
        conn.execute(
            """
            insert into macs (mac_installation_id, mac_secret_hash, app_install_id, display_name, created_at, last_seen_at)
            values (?, ?, null, ?, ?, ?)
            on conflict(mac_installation_id) do update set
              mac_secret_hash = excluded.mac_secret_hash,
              display_name = excluded.display_name,
              last_seen_at = excluded.last_seen_at
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


def insert_pairing_session(pairing_id: str, pairing_secret_hash: str, mac_id: str, expires_at: int):
    with db() as conn:
        conn.execute(
            """
            insert into pairing_sessions (pairing_id, pairing_secret_hash, mac_installation_id, expires_at, consumed_at)
            values (?, ?, ?, ?, null)
            """,
            (pairing_id, pairing_secret_hash, mac_id, expires_at),
        )


def pairing_session(pairing_id: str) -> PairingSessionRecord | None:
    with db() as conn:
        row = conn.execute(
            "select * from pairing_sessions where pairing_id = ?",
            (pairing_id,),
        ).fetchone()
    return PairingSessionRecord(**dict(row)) if row else None


def complete_pairing(app_install_id: str, mac_id: str, pairing_id: str, now: int):
    with db() as conn:
        conn.execute(
            """
            insert into app_installs (app_install_id, created_at, last_seen_at)
            values (?, ?, ?)
            on conflict(app_install_id) do update set last_seen_at = excluded.last_seen_at
            """,
            (app_install_id, now, now),
        )
        conn.execute(
            """
            update macs
            set app_install_id = ?, last_seen_at = ?
            where mac_installation_id = ?
            """,
            (app_install_id, now, mac_id),
        )
        conn.execute(
            "update pairing_sessions set consumed_at = ? where pairing_id = ?",
            (now, pairing_id),
        )


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
