#!/bin/bash
set -e

INSTALL_DIR="/opt/cloude-agent"
DATA_DIR="$HOME/.cloude-agent"
SUDO=""
if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
fi

echo "Installing Cloude Linux daemon..."

$SUDO mkdir -p "$INSTALL_DIR"
$SUDO cp -r ./* "$INSTALL_DIR/"
$SUDO chown -R "$USER":"$USER" "$INSTALL_DIR"
( cd "$INSTALL_DIR" && npm install --omit=dev )

mkdir -p "$DATA_DIR"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "Installing cloudflared..."
  ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
  case "$ARCH" in
    amd64|x86_64) CF_ARCH=amd64 ;;
    arm64|aarch64) CF_ARCH=arm64 ;;
    armhf|armv7l) CF_ARCH=arm ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
  esac
  $SUDO curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH" -o /usr/local/bin/cloudflared
  $SUDO chmod +x /usr/local/bin/cloudflared
fi

echo "Provisioning Cloudflare tunnel..."
PROVISION_OUT=$(node "$INSTALL_DIR/scripts/provision.js")
PAIRING_URL=$(echo "$PROVISION_OUT" | node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>console.log(JSON.parse(s).pairingURL))')
HOSTNAME_PUBLIC=$(echo "$PROVISION_OUT" | node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>console.log(JSON.parse(s).hostname))')

$SUDO tee /etc/systemd/system/cloude-agent.service > /dev/null << EOF
[Unit]
Description=Cloude Linux Daemon
After=network.target

[Service]
Type=simple
User=$USER
Environment=HOME=$HOME
Environment=CLOUDE_PORT=8765
Environment=CLOUDE_DATA=$DATA_DIR
Environment=PATH=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WorkingDirectory=$INSTALL_DIR
ExecStartPre=/bin/bash -c "fuser -k 8765/tcp 2>/dev/null || true"
ExecStart=/usr/bin/node $INSTALL_DIR/index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

$SUDO tee /etc/systemd/system/cloude-tunnel.service > /dev/null << EOF
[Unit]
Description=Cloude Cloudflare Tunnel
After=network.target cloude-agent.service
Requires=cloude-agent.service

[Service]
Type=simple
User=$USER
Environment=HOME=$HOME
Environment=CLOUDE_DATA=$DATA_DIR
ExecStart=/bin/bash $INSTALL_DIR/scripts/run-tunnel.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

$SUDO systemctl daemon-reload
$SUDO systemctl enable cloude-agent cloude-tunnel
$SUDO systemctl restart cloude-agent cloude-tunnel

echo ""
echo "Cloude Linux daemon installed."
echo "Public host: $HOSTNAME_PUBLIC"
echo "Pairing URL: $PAIRING_URL"
echo ""
if command -v qrencode >/dev/null 2>&1; then
  qrencode -t ansiutf8 "$PAIRING_URL"
else
  echo "(install qrencode to render a terminal QR)"
fi
