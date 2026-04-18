#!/bin/bash
set -euo pipefail

DEVICE_ID="${1:-booted}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${2:-$SCRIPT_DIR/output}"

mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_PATH="$OUT_DIR/simulator-$STAMP.png"

xcrun simctl io "$DEVICE_ID" screenshot "$OUT_PATH" >/dev/null
echo "$OUT_PATH"
