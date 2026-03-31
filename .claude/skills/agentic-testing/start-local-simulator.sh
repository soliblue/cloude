#!/bin/bash
set -euo pipefail

DEVICE_NAME="${1:-iPhone 17 Pro}"
HOST="${CLOUDE_SIM_HOST:-127.0.0.1}"
PORT="${CLOUDE_SIM_PORT:-8765}"
BUNDLE_ID="${CLOUDE_BUNDLE_ID:-soli.Cloude}"
DERIVED_DATA_PATH="${CLOUDE_SIM_DERIVED_DATA:-/tmp/cloude-sim-build}"
DEVICE_LINE="$(xcrun simctl list devices available | grep " ($DEVICE_NAME)" -m 1 || true)"

if [[ -z "$DEVICE_LINE" ]]; then
    DEVICE_LINE="$(xcrun simctl list devices available | grep "$DEVICE_NAME" -m 1 || true)"
fi

if [[ -z "$DEVICE_LINE" ]]; then
    echo "No available simulator named '$DEVICE_NAME'"
    exit 1
fi

DEVICE_ID="$(echo "$DEVICE_LINE" | grep -oE '[0-9A-F-]{36}' | head -1)"
if [[ -z "$DEVICE_ID" ]]; then
    echo "Could not resolve simulator UDID for '$DEVICE_NAME'"
    exit 1
fi

echo "Building and launching Mac agent..."
set -a
source .env
set +a
fastlane mac build_agent

TOKEN=""
for _ in {1..10}; do
    TOKEN="$(security find-generic-password -s com.cloude.agent -a authToken -w 2>/dev/null || true)"
    if [[ -n "$TOKEN" ]]; then
        break
    fi
    sleep 1
done

if [[ -z "$TOKEN" ]]; then
    echo "Cloude agent launched but no auth token was found in Keychain"
    exit 1
fi

if xcrun simctl list devices booted | grep -q "$DEVICE_ID"; then
    echo "Using already booted simulator $DEVICE_NAME ($DEVICE_ID)"
else
    echo "Booting simulator $DEVICE_NAME ($DEVICE_ID)..."
    open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID" >/dev/null 2>&1 || true
    xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$DEVICE_ID" -b
fi

echo "Building iOS app for $DEVICE_NAME..."
xcodebuild -project Cloude/Cloude.xcodeproj \
    -scheme Cloude \
    -destination "platform=iOS Simulator,id=$DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Cloude.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "Built Cloude.app not found at $APP_PATH"
    exit 1
fi

echo "Installing app into simulator $DEVICE_ID..."
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

sleep 1

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
