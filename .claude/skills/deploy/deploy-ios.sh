#!/bin/bash
set -e

# Deploy iOS app - checks for connected iPhone first, falls back to TestFlight
# Usage: ./deploy-ios.sh [--phone-only]

PHONE_ONLY=false
if [[ "$1" == "--phone-only" ]]; then
    PHONE_ONLY=true
fi

echo "🔍 Checking for connected iPhone..."

# Check if iPhone is connected
DEVICE_LINE=$(xcrun devicectl list devices 2>&1 | grep "My iPhone" || true)

if [[ -z "$DEVICE_LINE" ]]; then
    if [[ "$PHONE_ONLY" == true ]]; then
        echo "❌ iPhone not connected and --phone-only flag set"
        exit 1
    fi
    echo "📱 iPhone not connected, falling back to TestFlight..."
    source .env && fastlane ios beta_local
    exit 0
fi

# Extract device UUID and state (handle device name with spaces)
# Format: "My iPhone   hostname   UUID   state   model"
DEVICE_UUID=$(echo "$DEVICE_LINE" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9A-F]{8}-/) print $i}')
DEVICE_STATE=$(echo "$DEVICE_LINE" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9A-F]{8}-/) print $(i+1)}')

if [[ "$DEVICE_STATE" != "connected" ]]; then
    if [[ "$PHONE_ONLY" == true ]]; then
        echo "❌ iPhone is $DEVICE_STATE, not connected (--phone-only flag set)"
        exit 1
    fi
    echo "📱 iPhone is $DEVICE_STATE, falling back to TestFlight..."
    source .env && fastlane ios beta_local
    exit 0
fi

echo "✅ iPhone connected (UUID: $DEVICE_UUID)"
echo "🔨 Building iOS app..."

# Build for connected device
xcodebuild -project Cloude/Cloude.xcodeproj \
    -scheme Cloude \
    -destination "platform=iOS,name=My iPhone" \
    build 2>&1 | tail -5

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "❌ Build failed"
    exit 1
fi

echo "📲 Installing to iPhone..."

# Install to device
xcrun devicectl device install app \
    --device "$DEVICE_UUID" \
    /Users/soli/Library/Developer/Xcode/DerivedData/Cloude-drgeixundgtalkdkjnittevjxsyt/Build/Products/Debug-iphoneos/Cloude.app

if [[ $? -eq 0 ]]; then
    echo "✅ Installed directly to iPhone"
    exit 0
else
    echo "❌ Install failed"
    exit 1
fi
