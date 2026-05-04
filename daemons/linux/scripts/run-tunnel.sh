#!/bin/bash
set -e
DATA_DIR="${CLOUDE_DATA:-$HOME/.cloude-agent}"
TOKEN=$(node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('$DATA_DIR/tunnel.json','utf8')).tunnelToken)")
exec /usr/local/bin/cloudflared tunnel run --token "$TOKEN"
