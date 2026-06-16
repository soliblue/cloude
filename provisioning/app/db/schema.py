from app.db.connection import db


def init_db():
    with db() as conn:
        conn.executescript(
            """
            create table if not exists macs (
              mac_installation_id text primary key,
              mac_secret_hash text not null,
              app_install_id text,
              display_name text not null,
              created_at integer not null,
              last_seen_at integer not null
            );

            create table if not exists tunnels (
              mac_installation_id text primary key,
              cloudflare_tunnel_id text not null,
              hostname text not null unique,
              dns_record_id text not null,
              status text not null,
              created_at integer not null,
              last_heartbeat_at integer
            );
            """
        )
