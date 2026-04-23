#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/daemons/macos/macOSDaemon.xcodeproj"
SCHEME_NAME="Cloude Agent"
PRODUCT_NAME="Remote CC Daemon"
DERIVED_DATA_PATH="$ROOT_DIR/build/vscode-daemon"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/$PRODUCT_NAME.app"

pkill -x "$PRODUCT_NAME" 2>/dev/null || true

echo "Building $SCHEME_NAME"
xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" -configuration Debug -derivedDataPath "$DERIVED_DATA_PATH" CODE_SIGNING_ALLOWED=NO build

CLOUDFLARED_PATH="${CLOUDFLARED_PATH:-$(command -v cloudflared || true)}"
if [[ -n "$CLOUDFLARED_PATH" ]]; then
  rm -f "$APP_PATH/Contents/Resources/cloudflared"
  cp "$CLOUDFLARED_PATH" "$APP_PATH/Contents/Resources/cloudflared"
  chmod +w "$APP_PATH/Contents/Resources/cloudflared"
  chmod +x "$APP_PATH/Contents/Resources/cloudflared"
fi

echo "Launching $PRODUCT_NAME"
exec "$APP_PATH/Contents/MacOS/$PRODUCT_NAME"
