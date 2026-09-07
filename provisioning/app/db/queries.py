from secrets import token_urlsafe

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


def upsert_push_device(mac_id: str, device_id: str, token: str, environment: str, app_bundle_id: str, now: int):
    with db() as conn:
        conn.execute(
            """
            insert into push_devices
              (mac_installation_id, device_id, token, environment, app_bundle_id, created_at, last_seen_at)
            values (?, ?, ?, ?, ?, ?, ?)
            on conflict(mac_installation_id, device_id) do update set
              token = excluded.token,
              environment = excluded.environment,
              app_bundle_id = excluded.app_bundle_id,
              last_seen_at = excluded.last_seen_at
            """,
            (mac_id, device_id, token, environment, app_bundle_id, now, now),
        )


def delete_push_device(mac_id: str, device_id: str) -> bool:
    with db() as conn:
        cursor = conn.execute(
            "delete from push_devices where mac_installation_id = ? and device_id = ?",
            (mac_id, device_id),
        )
    return cursor.rowcount > 0


def push_devices(mac_id: str):
    with db() as conn:
        rows = conn.execute(
            "select * from push_devices where mac_installation_id = ?",
            (mac_id,),
        ).fetchall()
    return [dict(row) for row in rows]


def _event_key(mac_id: str, event_id: str) -> str:
    return f"{mac_id}:{event_id}"


def claim_notification(mac_id: str, event_id: str, now: int, lease_seconds: int = 30) -> tuple[str, str | None]:
    key = _event_key(mac_id, event_id)
    owner = token_urlsafe(18)
    with db() as conn:
        conn.execute("begin immediate")
        conn.execute(
            "delete from notification_deliveries where event_id in (select event_id from notification_events where delivered_at is not null and delivered_at < ?)",
            (now - 30 * 24 * 60 * 60,),
        )
        conn.execute(
            "delete from notification_events where delivered_at is not null and delivered_at < ?",
            (now - 30 * 24 * 60 * 60,),
        )
        cursor = conn.execute(
            "insert or ignore into notification_events (event_id, mac_installation_id, created_at) values (?, ?, ?)",
            (key, mac_id, now),
        )
        row = conn.execute(
            "select delivered_at, lease_until from notification_events where event_id = ? and mac_installation_id = ?",
            (key, mac_id),
        ).fetchone()
        if row["delivered_at"]:
            return "delivered", None
        if row["lease_until"] and row["lease_until"] > now:
            return "busy", None
        conn.execute(
            "update notification_events set lease_until = ?, lease_owner = ? where event_id = ? and mac_installation_id = ?",
            (now + lease_seconds, owner, key, mac_id),
        )
    return "claimed", owner


def notification_delivered(mac_id: str, event_id: str) -> bool:
    with db() as conn:
        row = conn.execute(
            "select delivered_at from notification_events where event_id = ? and mac_installation_id = ?",
            (_event_key(mac_id, event_id), mac_id),
        ).fetchone()
    return bool(row and row["delivered_at"])


def delivered_devices(mac_id: str, event_id: str) -> set[str]:
    with db() as conn:
        rows = conn.execute(
            "select device_id from notification_deliveries where event_id = ?",
            (_event_key(mac_id, event_id),),
        ).fetchall()
    return {row["device_id"] for row in rows}


def renew_notification(mac_id: str, event_id: str, owner: str, now: int, lease_seconds: int = 30) -> bool:
    with db() as conn:
        cursor = conn.execute(
            "update notification_events set lease_until = ? where event_id = ? and mac_installation_id = ? and lease_owner = ? and (lease_until is null or lease_until > ?)",
            (now + lease_seconds, _event_key(mac_id, event_id), mac_id, owner, now),
        )
    return cursor.rowcount > 0


def mark_device_delivered(mac_id: str, event_id: str, owner: str, device_id: str, now: int) -> bool:
    with db() as conn:
        active = conn.execute(
            "select 1 from notification_events where event_id = ? and mac_installation_id = ? and lease_owner = ? and lease_until > ? and delivered_at is null",
            (_event_key(mac_id, event_id), mac_id, owner, now),
        ).fetchone()
        if not active:
            return False
        conn.execute(
            "insert or ignore into notification_deliveries (event_id, device_id, delivered_at) values (?, ?, ?)",
            (_event_key(mac_id, event_id), device_id, now),
        )
    return True


def complete_notification(mac_id: str, event_id: str, owner: str, now: int) -> bool:
    with db() as conn:
        cursor = conn.execute("update notification_events set delivered_at = ?, lease_until = null, lease_owner = null where event_id = ? and mac_installation_id = ? and lease_owner = ? and lease_until > ?", (now, _event_key(mac_id, event_id), mac_id, owner, now))
    return cursor.rowcount > 0


def forget_notification(mac_id: str, event_id: str, owner: str):
    with db() as conn:
        conn.execute("update notification_events set delivered_at = null, lease_until = null, lease_owner = null where event_id = ? and mac_installation_id = ? and lease_owner = ?", (_event_key(mac_id, event_id), mac_id, owner))


def delete_push_token(mac_id: str, token: str):
    with db() as conn:
        conn.execute("delete from push_devices where mac_installation_id = ? and token = ?", (mac_id, token))
