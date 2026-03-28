#!/bin/bash
set -euo pipefail

DEVICE_NAME="${1:-iPhone 17 Pro}"
HOST="${CLOUDE_SIM_HOST:-127.0.0.1}"
PORT="${CLOUDE_SIM_PORT:-8765}"
BUNDLE_ID="${CLOUDE_BUNDLE_ID:-soli.Cloude}"
DERIVED_DATA_PATH="${CLOUDE_SIM_DERIVED_DATA:-/tmp/cloude-sim-build}"
TOKEN="$(security find-generic-password -s com.cloude.agent -a authToken -w)"

if [[ -z "$TOKEN" ]]; then
    echo "Missing Cloude agent token in Keychain"
    exit 1
fi

echo "Building and launching Mac agent..."
source .env
fastlane mac build_agent

BOOTED_DEVICE_LINE="$(xcrun simctl list devices booted | grep "$DEVICE_NAME" | head -1 || true)"
if [[ -z "$BOOTED_DEVICE_LINE" ]]; then
    echo "No booted simulator named '$DEVICE_NAME'"
    exit 1
fi

DEVICE_ID="$(echo "$BOOTED_DEVICE_LINE" | grep -oE '[0-9A-F-]{36}' | head -1)"
if [[ -z "$DEVICE_ID" ]]; then
    echo "Could not resolve booted simulator UDID"
    exit 1
fi

echo "Building iOS app for $DEVICE_NAME..."
xcodebuild -project Cloude/Cloude.xcodeproj \
    -scheme Cloude \
    -destination "platform=iOS Simulator,name=$DEVICE_NAME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Cloude.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "Built Cloude.app not found at $APP_PATH"
    exit 1
fi

echo "Installing app into simulator $DEVICE_ID..."
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

echo "Writing local environment into simulator container..."
CLOUDE_SIM_HOST="$HOST" \
CLOUDE_SIM_PORT="$PORT" \
CLOUDE_SIM_TOKEN="$TOKEN" \
CLOUDE_SIM_SYMBOL="desktopcomputer" \
"$(dirname "$0")/configure-simulator-env.sh" "$DEVICE_ID" "$BUNDLE_ID"

echo "Launching app..."
xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID"

echo "Simulator app launched"
echo "Device: $DEVICE_NAME ($DEVICE_ID)"
echo "Host: $HOST:$PORT"
echo "Bundle: $BUNDLE_ID"
