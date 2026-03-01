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

echo "📲 Installing to iPhone..."

DEVICECTL_UUID=$(xcrun devicectl list devices 2>&1 | grep -i "iphone" | grep "connected" \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Cloude-*/Build/Products/Release-iphoneos/Cloude.app -maxdepth 0 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
    echo "❌ Could not find built Cloude.app in DerivedData"
    exit 1
fi

xcrun devicectl device install app \
    --device "$DEVICECTL_UUID" \
    "$APP_PATH"

if [[ $? -eq 0 ]]; then
    echo "✅ Installed directly to $XCODE_NAME"
    exit 0
else
    echo "❌ Install failed"
    exit 1
fi
