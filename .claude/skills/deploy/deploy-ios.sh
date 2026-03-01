#!/bin/bash
set -e

# Deploy iOS app
# Default: TestFlight
# --phone: Install directly to connected iPhone (skip TestFlight)

MODE="testflight"
if [[ "$1" == "--phone" ]]; then
    MODE="phone"
fi

if [[ "$MODE" == "testflight" ]]; then
    echo "🚀 Deploying to TestFlight..."
    source .env && fastlane ios beta_local
    exit 0
fi

echo "🔍 Checking for connected iPhone..."

XCODE_DEVICE=$(xcodebuild -project Cloude/Cloude.xcodeproj -scheme Cloude -showdestinations 2>&1 \
    | grep "platform:iOS, arch:" | grep -i "iphone" | head -1 || true)

if [[ -z "$XCODE_DEVICE" ]]; then
    echo "❌ iPhone not connected"
    exit 1
fi

XCODE_ID=$(echo "$XCODE_DEVICE" | grep -oE 'id:[^,}]+' | sed 's/id://')
XCODE_NAME=$(echo "$XCODE_DEVICE" | grep -oE 'name:[^}]+' | sed 's/name://')

echo "✅ $XCODE_NAME connected (ID: $XCODE_ID)"
echo "🔨 Building and installing iOS app..."

xcodebuild -project Cloude/Cloude.xcodeproj \
    -scheme Cloude \
    -configuration Release \
    -destination "platform=iOS,id=$XCODE_ID" \
    build 2>&1 | tail -5

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Installed directly to $XCODE_NAME"
