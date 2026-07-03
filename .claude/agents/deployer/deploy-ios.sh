#!/bin/bash
set -euo pipefail

PHONE_ONLY=false
TESTFLIGHT_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phone | --phone-only)
            PHONE_ONLY=true
            shift
            ;;
        --testflight | --force-testflight)
            TESTFLIGHT_ONLY=true
            shift
            ;;
        *)
            echo "Unknown arg: $1"
            exit 1
            ;;
    esac
done

if [[ "$TESTFLIGHT_ONLY" == true && "$PHONE_ONLY" == true ]]; then
    echo "❌ --testflight and --phone are mutually exclusive"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
IOS_BUILD_DIR="/tmp/cloude-ios-device-build"
APP_PATH="$IOS_BUILD_DIR/Build/Products/Debug-iphoneos/Cloude.app"
BUNDLE_ID="soli.Cloude"

if [[ "$(uname -s)" != "Darwin" ]]; then
    if [[ "$PHONE_ONLY" == true ]]; then
        echo "❌ --phone needs a Mac with Xcode; cannot install to a device from $(uname -s)"
        exit 1
    fi
    echo "🐧 No Xcode on $(uname -s); deploying to TestFlight via GitHub Actions..."
    N=1
    while ! git -C "$REPO_ROOT" tag "v$(date +%Y.%m.%d).$N" 2>/dev/null; do
        N=$((N + 1))
    done
    TAG="v$(date +%Y.%m.%d).$N"
    git -C "$REPO_ROOT" push origin "$TAG"
    echo "✅ Pushed $TAG; testflight.yml will build and upload to TestFlight."
    echo "Monitor: https://github.com/soliblue/cloude/actions/workflows/testflight.yml"
    exit 0
fi

if [[ "$TESTFLIGHT_ONLY" == true ]]; then
    echo "🚀 Forcing TestFlight upload..."
    cd "$REPO_ROOT"
    set -a
    source .env
    set +a
    fastlane ios beta_local
    exit 0
fi

echo "🔍 Checking for connected iPhone..."

XCODE_DEVICE=$(xcodebuild -project "$REPO_ROOT/clients/ios/iOS.xcodeproj" -scheme Cloude -showdestinations 2>&1 \
    | grep "platform:iOS, arch:" | grep -i "iphone" | head -1 || true)

if [[ -z "$XCODE_DEVICE" ]]; then
    if [[ "$PHONE_ONLY" == true ]]; then
        echo "❌ iPhone not connected and --phone-only flag set"
        exit 1
    fi
    echo "📱 iPhone not connected, falling back to TestFlight..."
    cd "$REPO_ROOT"
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

rm -rf "$IOS_BUILD_DIR"

set +e
xcodebuild -project "$REPO_ROOT/clients/ios/iOS.xcodeproj" \
    -scheme Cloude \
    -configuration Debug \
    -destination "platform=iOS,id=$XCODE_ID" \
    -derivedDataPath "$IOS_BUILD_DIR" \
    build 2>&1 | tail -5
BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [[ $BUILD_STATUS -ne 0 ]]; then
    echo "❌ Build failed"
    exit 1
fi

echo "📲 Installing to iPhone..."

if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Could not find built Cloude.app at $APP_PATH"
    exit 1
fi

if xcrun devicectl device install app \
    --device "$XCODE_ID" \
    "$APP_PATH"; then
    echo "✅ Installed directly to $XCODE_NAME"
else
    echo "❌ Install failed"
    exit 1
fi

echo "🚀 Launching on iPhone..."

if xcrun devicectl device process launch \
    --device "$XCODE_ID" \
    --terminate-existing \
    "$BUNDLE_ID"; then
    echo "✅ Launched $BUNDLE_ID on $XCODE_NAME"
    exit 0
else
    echo "❌ Launch failed"
    exit 1
fi
