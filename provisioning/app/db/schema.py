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

            create table if not exists push_devices (
              mac_installation_id text not null,
              device_id text not null,
              token text not null,
              environment text not null,
              app_bundle_id text not null,
              created_at integer not null,
              last_seen_at integer not null,
              primary key (mac_installation_id, device_id),
              foreign key (mac_installation_id) references macs(mac_installation_id)
            );

            create table if not exists notification_events (
              event_id text primary key,
              mac_installation_id text not null,
              created_at integer not null,
              delivered_at integer,
              lease_until integer,
              lease_owner text,
              foreign key (mac_installation_id) references macs(mac_installation_id)
            );

            create table if not exists notification_deliveries (
              event_id text not null,
              device_id text not null,
              delivered_at integer not null,
              primary key (event_id, device_id),
              foreign key (event_id) references notification_events(event_id)
            );

            create index if not exists notification_events_created_at
              on notification_events(created_at);
            """
        )
        columns = {row[1] for row in conn.execute("pragma table_info(notification_events)")}
        if "lease_until" not in columns:
            conn.execute("alter table notification_events add column lease_until integer")
        if "lease_owner" not in columns:
            conn.execute("alter table notification_events add column lease_owner text")
