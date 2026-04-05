#!/bin/bash
set -euo pipefail

DEVICE_ID="${1:-booted}"
OUT_DIR="${2:-/tmp/cloude-simulator-shots}"

mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_PATH="$OUT_DIR/simulator-$STAMP.png"

xcrun simctl io "$DEVICE_ID" screenshot "$OUT_PATH" >/dev/null
echo "$OUT_PATH"
