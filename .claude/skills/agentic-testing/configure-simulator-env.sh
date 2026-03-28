#!/bin/bash
set -euo pipefail

DEVICE_ID="${1:-booted}"
BUNDLE_ID="${2:-soli.Cloude}"
HOST="${CLOUDE_SIM_HOST:-127.0.0.1}"
PORT="${CLOUDE_SIM_PORT:-8765}"
TOKEN="${CLOUDE_SIM_TOKEN:-$(security find-generic-password -s com.cloude.agent -a authToken -w)}"
SYMBOL="${CLOUDE_SIM_SYMBOL:-desktopcomputer}"
ENV_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
CONTAINER_PATH="$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data)"
DOCUMENTS_PATH="$CONTAINER_PATH/Documents"
PREFERENCES_DOMAIN="$CONTAINER_PATH/Library/Preferences/soli.Cloude"

mkdir -p "$DOCUMENTS_PATH"
cat > "$DOCUMENTS_PATH/environments.json" <<EOF
[
  {
    "id": "$ENV_ID",
    "host": "$HOST",
    "port": $PORT,
    "token": "$TOKEN",
    "symbol": "$SYMBOL"
  }
]
EOF

defaults write "$PREFERENCES_DOMAIN" activeEnvironmentId -string "$ENV_ID"

echo "Configured simulator environment"
echo "Device: $DEVICE_ID"
echo "Bundle: $BUNDLE_ID"
echo "Host: $HOST:$PORT"
echo "Environment ID: $ENV_ID"
