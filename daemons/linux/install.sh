#!/bin/bash
set -e

INSTALL_DIR="/opt/cloude-agent"
DATA_DIR="$HOME/.cloude-agent"

echo "Installing Cloude Linux daemon..."

sudo mkdir -p "$INSTALL_DIR"
sudo cp -r ./* "$INSTALL_DIR/"
cd "$INSTALL_DIR"
sudo npm install --production

mkdir -p "$DATA_DIR"

# Create systemd service
sudo tee /etc/systemd/system/cloude-agent.service > /dev/null << EOF
[Unit]
Description=Cloude Linux Daemon
After=network.target

[Service]
Type=simple
User=$USER
Environment=HOME=$HOME
Environment=CLOUDE_PORT=8765
Environment=CLOUDE_DATA=$DATA_DIR
ExecStart=/usr/bin/node $INSTALL_DIR/index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable cloude-agent
sudo systemctl start cloude-agent

echo ""
echo "Cloude Linux daemon installed and running!"
echo "Auth token: $(cat $DATA_DIR/auth-token 2>/dev/null || echo 'will be generated on first start')"
echo "Port: 8765"
echo "Ping without auth: curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8765/ping"
echo "Ping with auth: curl -s -H \"Authorization: Bearer \$(cat $DATA_DIR/auth-token)\" http://127.0.0.1:8765/ping"
echo ""
echo "Commands:"
echo "  sudo systemctl status cloude-agent"
echo "  sudo systemctl restart cloude-agent"
echo "  journalctl -u cloude-agent -f"
