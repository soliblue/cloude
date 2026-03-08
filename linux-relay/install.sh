#!/bin/bash
set -e

INSTALL_DIR="/opt/cloude-agent"
DATA_DIR="$HOME/.cloude-agent"

echo "Installing Cloude Agent..."

sudo mkdir -p "$INSTALL_DIR"
sudo cp -r ./* "$INSTALL_DIR/"
cd "$INSTALL_DIR"
sudo npm install --production

mkdir -p "$DATA_DIR"

# Install cloude stub CLI
CLAUDE_DIR=$(dirname $(which claude 2>/dev/null || echo "/usr/local/bin/claude"))
sudo tee "$CLAUDE_DIR/cloude" > /dev/null << 'STUB'
#!/bin/bash
exit 0
STUB
sudo chmod 755 "$CLAUDE_DIR/cloude"

# Create systemd service
sudo tee /etc/systemd/system/cloude-agent.service > /dev/null << EOF
[Unit]
Description=Cloude Agent
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
echo "Cloude Agent installed and running!"
echo "Auth token: $(cat $DATA_DIR/auth-token 2>/dev/null || echo 'will be generated on first start')"
echo "Port: 8765"
echo "Logs: $DATA_DIR/logs/"
echo ""
echo "Commands:"
echo "  sudo systemctl status cloude-agent"
echo "  sudo systemctl restart cloude-agent"
echo "  journalctl -u cloude-agent -f"
