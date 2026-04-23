#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
PROVISIONING_DIR="$ROOT_DIR/provisioning"
REMOTE="${REMOTECC_DEPLOY_TARGET:-root@178.104.0.187}"
REMOTE_DIR="${REMOTECC_REMOTE_DIR:-/opt/remotecc/provisioning}"
REMOTE_ENV_DIR="${REMOTECC_ENV_DIR:-/etc/remotecc}"
REMOTE_DATA_DIR="${REMOTECC_DATA_DIR:-/var/lib/remotecc}"
SERVICE_NAME="${REMOTECC_SERVICE_NAME:-remotecc-provisioning}"
CLOUDFLARED_SERVICE_NAME="${REMOTECC_CLOUDFLARED_SERVICE_NAME:-remotecc-provisioning-cloudflared}"
PROVISIONING_HOSTNAME="${REMOTECC_PUBLIC_HOSTNAME:-remotecc.soli.blue}"
MAC_TUNNEL_HOST_SUFFIX="${REMOTECC_MAC_TUNNEL_HOST_SUFFIX:-soli.blue}"
MAC_TUNNEL_HOST_LABEL_SUFFIX="${REMOTECC_MAC_TUNNEL_HOST_LABEL_SUFFIX:-remotecc}"
LOCAL_PYTHON="${LOCAL_PYTHON:-python3.13}"

set -a
source "$ROOT_DIR/.env"
set +a

existing_provisioning_secret="$(ssh "$REMOTE" "test -f '$REMOTE_ENV_DIR/provisioning.env' && sed -n 's/^PROVISIONING_TOKEN_SECRET=//p' '$REMOTE_ENV_DIR/provisioning.env' | head -1 || true")"
export EXISTING_PROVISIONING_TOKEN_SECRET="$existing_provisioning_secret"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

"$LOCAL_PYTHON" - "$tmp_dir" "$PROVISIONING_HOSTNAME" "$MAC_TUNNEL_HOST_SUFFIX" "$MAC_TUNNEL_HOST_LABEL_SUFFIX" <<'PY'
import json
import os
import secrets
import sys
import urllib.error
import urllib.request

tmp_dir, provisioning_hostname, mac_suffix, mac_label_suffix = sys.argv[1:]
base = "https://api.cloudflare.com/client/v4"
account_id = os.environ["CLOUDFLARE_ACCOUNT_ID"]
zone_id = os.environ["CLOUDFLARE_ZONE_ID"]
api_token = os.environ["CLOUDFLARE_API_TOKEN"]
headers = {
    "Authorization": f"Bearer {api_token}",
    "Content-Type": "application/json",
}

def request(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        payload = json.loads(error.read().decode())
        raise SystemExit(json.dumps(payload, indent=2))
    if payload.get("success"):
        return payload["result"]
    raise SystemExit(json.dumps(payload, indent=2))

tunnel_name = "remotecc-provisioning-medina"
tunnels = request("GET", f"/accounts/{account_id}/cfd_tunnel?per_page=100")
tunnel = next((item for item in tunnels if item.get("name") == tunnel_name and item.get("deleted_at") is None), None)
if tunnel is None:
    tunnel = request("POST", f"/accounts/{account_id}/cfd_tunnel", {"name": tunnel_name, "config_src": "cloudflare"})

tunnel_id = tunnel["id"]
target = f"{tunnel_id}.cfargotunnel.com"
records = request("GET", f"/zones/{zone_id}/dns_records?name={provisioning_hostname}")
record = records[0] if records else None
if record:
    request("PUT", f"/zones/{zone_id}/dns_records/{record['id']}", {"type": "CNAME", "name": provisioning_hostname, "content": target, "proxied": True})
else:
    request("POST", f"/zones/{zone_id}/dns_records", {"type": "CNAME", "name": provisioning_hostname, "content": target, "proxied": True})

request("PUT", f"/accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations", {
    "config": {
        "ingress": [
            {"hostname": provisioning_hostname, "service": "http://localhost:8080"},
            {"service": "http_status:404"},
        ]
    }
})

tunnel_token = request("GET", f"/accounts/{account_id}/cfd_tunnel/{tunnel_id}/token")
provisioning_secret = os.environ.get("PROVISIONING_TOKEN_SECRET") or os.environ.get("EXISTING_PROVISIONING_TOKEN_SECRET") or secrets.token_urlsafe(48)

with open(f"{tmp_dir}/provisioning.env", "w") as file:
    file.write(f"CLOUDFLARE_ACCOUNT_ID={account_id}\n")
    file.write(f"CLOUDFLARE_ZONE_ID={zone_id}\n")
    file.write(f"CLOUDFLARE_API_TOKEN={api_token}\n")
    file.write(f"PUBLIC_BASE_URL=https://{provisioning_hostname}\n")
    file.write("DATABASE_PATH=/var/lib/remotecc/provisioning.db\n")
    file.write(f"PROVISIONING_TOKEN_SECRET={provisioning_secret}\n")
    file.write("PAIRING_TTL_SECONDS=300\n")
    file.write("RATE_LIMIT_AUTH_ATTEMPTS_PER_MINUTE=20\n")
    file.write("RATE_LIMIT_HEARTBEAT_PER_MINUTE=120\n")
    file.write("RATE_LIMIT_REGISTER_PER_HOUR=20\n")
    file.write("RATE_LIMIT_TUNNEL_MUTATIONS_PER_HOUR=30\n")
    file.write(f"TUNNEL_HOST_SUFFIX={mac_suffix}\n")
    file.write(f"TUNNEL_HOST_LABEL_SUFFIX={mac_label_suffix}\n")
    file.write("TUNNEL_ORIGIN_SERVICE=http://localhost:8765\n")

with open(f"{tmp_dir}/cloudflared.env", "w") as file:
    file.write(f"TUNNEL_TOKEN={tunnel_token}\n")

with open(f"{tmp_dir}/summary.json", "w") as file:
    json.dump({"tunnel": tunnel_name, "tunnelId": tunnel_id, "hostname": provisioning_hostname}, file)
PY

ssh "$REMOTE" "mkdir -p '$REMOTE_DIR' '$REMOTE_ENV_DIR' '$REMOTE_DATA_DIR'"

rsync -az --delete \
  --exclude '.venv' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '*.db' \
  "$PROVISIONING_DIR/" "$REMOTE:$REMOTE_DIR/"

scp "$tmp_dir/provisioning.env" "$tmp_dir/cloudflared.env" "$REMOTE:/tmp/"

ssh "$REMOTE" "set -e
mkdir -p '$REMOTE_ENV_DIR' '$REMOTE_DATA_DIR'
mv /tmp/provisioning.env '$REMOTE_ENV_DIR/provisioning.env'
mv /tmp/cloudflared.env '$REMOTE_ENV_DIR/cloudflared.env'
chmod 600 '$REMOTE_ENV_DIR/provisioning.env' '$REMOTE_ENV_DIR/cloudflared.env'
chown root:root '$REMOTE_ENV_DIR/provisioning.env' '$REMOTE_ENV_DIR/cloudflared.env'
chown -R soli:soli '$REMOTE_DIR' '$REMOTE_DATA_DIR'
cd '$REMOTE_DIR'
python3 -m venv .venv
.venv/bin/pip install -q -r requirements.txt
cat > /etc/systemd/system/$SERVICE_NAME.service <<'UNIT'
[Unit]
Description=RemoteCC Provisioning
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=soli
WorkingDirectory=$REMOTE_DIR
EnvironmentFile=$REMOTE_ENV_DIR/provisioning.env
ExecStart=$REMOTE_DIR/.venv/bin/gunicorn app.main:app --worker-class uvicorn.workers.UvicornWorker --workers 1 --bind 127.0.0.1:8080
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
cat > /etc/systemd/system/$CLOUDFLARED_SERVICE_NAME.service <<'UNIT'
[Unit]
Description=Cloudflare Tunnel for RemoteCC Provisioning
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=soli
EnvironmentFile=$REMOTE_ENV_DIR/cloudflared.env
ExecStart=/usr/bin/cloudflared tunnel run --token \${TUNNEL_TOKEN}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now '$SERVICE_NAME.service' '$CLOUDFLARED_SERVICE_NAME.service'
systemctl restart '$SERVICE_NAME.service' '$CLOUDFLARED_SERVICE_NAME.service'
systemctl --no-pager --full status '$SERVICE_NAME.service' '$CLOUDFLARED_SERVICE_NAME.service' >/dev/null
"

sleep 2
if ! curl -fsS --retry 5 --retry-delay 2 "https://$PROVISIONING_HOSTNAME/health" >/dev/null 2>/dev/null; then
  edge_ip="$(dig @1.1.1.1 +short "$PROVISIONING_HOSTNAME" | head -1)"
  if [[ -n "$edge_ip" ]]; then
    curl -fsS --resolve "$PROVISIONING_HOSTNAME:443:$edge_ip" "https://$PROVISIONING_HOSTNAME/health" >/dev/null
  else
    ssh "$REMOTE" "curl -fsS http://127.0.0.1:8080/health >/dev/null"
  fi
fi
"$LOCAL_PYTHON" - "$tmp_dir/summary.json" <<'PY'
import json
import sys
with open(sys.argv[1]) as file:
    data = json.load(file)
print(f"Deployed {data['hostname']} via tunnel {data['tunnel']} ({data['tunnelId']})")
PY
