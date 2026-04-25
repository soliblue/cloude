#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DISMISSER="$SCRIPT_DIR/../../launcher/dismiss-sim-alerts.sh"
ROUTE="${1:-settings}"
UDID="${2:-${SIMULATOR_UDID:-booted}}"

case "$ROUTE" in
  settings)         URL="cloude://settings" ;;
  screenshot)       URL="cloude://screenshot" ;;
  new-window)       URL="cloude://window/new" ;;
  close-window)     URL="cloude://window/close" ;;
  chat-tab)         URL="cloude://session/tab?value=chat" ;;
  files-tab)        URL="cloude://session/tab?value=files" ;;
  git-tab)          URL="cloude://session/tab?value=git" ;;
  auto-model)       URL="cloude://session/model?value=auto" ;;
  haiku-model)      URL="cloude://session/model?value=haiku" ;;
  default-effort)   URL="cloude://session/effort?value=default" ;;
  low-effort)       URL="cloude://session/effort?value=low" ;;
  abort)            URL="cloude://chat/abort" ;;
  *)                URL="$ROUTE" ;;
esac

if [[ -x "$DISMISSER" ]]; then
  "$DISMISSER" 8 >/dev/null 2>&1 &
fi
xcrun simctl openurl "$UDID" "$URL"
sleep 2
