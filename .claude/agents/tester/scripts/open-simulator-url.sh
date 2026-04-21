#!/usr/bin/env bash
set -euo pipefail

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
  abort)            URL="cloude://chat/abort" ;;
  *)                URL="$ROUTE" ;;
esac

xcrun simctl openurl "$UDID" "$URL"
