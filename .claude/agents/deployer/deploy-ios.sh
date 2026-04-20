#!/bin/bash
set -e

# Deploy iOS app - checks for connected iPhone first, falls back to TestFlight
# Usage: ./deploy-ios.sh [--phone-only]

PHONE_ONLY=false
if [[ "$1" == "--phone-only" ]]; then
    PHONE_ONLY=true
fi

echo "🔍 Checking for connected iPhone..."

# Get xcodebuild device ID (different from devicectl UUID)
XCODE_DEVICE=$(xcodebuild -project clients/ios/iOS.xcodeproj -scheme Cloude -showdestinations 2>&1 \
    | grep "platform:iOS, arch:" | grep -i "iphone" | head -1 || true)

if [[ -z "$XCODE_DEVICE" ]]; then
    if [[ "$PHONE_ONLY" == true ]]; then
        echo "❌ iPhone not connected and --phone-only flag set"
        exit 1
    fi
    echo "📱 iPhone not connected, falling back to TestFlight..."
    set -a
    source .env
    set +a
    fastlane ios beta_local
    exit 0
fi

XCODE_ID=$(echo "$XCODE_DEVICE" | grep -oE 'id:[^,}]+' | sed 's/id://')
XCODE_NAME=$(echo "$XCODE_DEVICE" | grep -oE 'name:[^}]+' | sed 's/name://')

echo "✅ $XCODE_NAME connected (ID: $XCODE_ID)"
echo "🔨 Building and installing iOS app..."

# Build for connected device
xcodebuild -project clients/ios/iOS.xcodeproj \
    -scheme Cloude \
    -destination "platform=iOS,id=$XCODE_ID" \
    build 2>&1 | tail -5

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "❌ Build failed"
    exit 1
fi

echo "📲 Installing to iPhone..."

# Get devicectl UUID for install
DEVICECTL_UUID=$(xcrun devicectl list devices 2>&1 | grep -i "iphone" | grep "connected" \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)

# Find the built app in DerivedData
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Cloude-*/Build/Products/Debug-iphoneos/Cloude.app -maxdepth 0 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
    echo "❌ Could not find built Cloude.app in DerivedData"
    exit 1
fi

# Install to device
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
