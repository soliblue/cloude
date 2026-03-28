#!/bin/bash
set -euo pipefail

ROUTE="${1:-settings}"
DEVICE_ID="${2:-booted}"

case "$ROUTE" in
    settings) URL="cloude://settings" ;;
    memory) URL="cloude://memory" ;;
    memories) URL="cloude://memories" ;;
    plans) URL="cloude://plans" ;;
    whiteboard) URL="cloude://whiteboard" ;;
    whiteboard-snapshot) URL="cloude://whiteboard/snapshot" ;;
    whiteboard-export) URL="cloude://whiteboard/export" ;;
    usage) URL="cloude://usage" ;;
    search) URL="cloude://search" ;;
    new-chat) URL="cloude://conversation/new" ;;
    duplicate-chat) URL="cloude://conversation/duplicate" ;;
    refresh-chat) URL="cloude://conversation/refresh" ;;
    stop-run) URL="cloude://run/stop" ;;
    screenshot) URL="cloude://screenshot" ;;
    window-edit) URL="cloude://window/edit" ;;
    window-close) URL="cloude://window/close" ;;
    new-files-window) URL="cloude://window/new?type=files" ;;
    new-git-window) URL="cloude://window/new?type=gitChanges" ;;
    chat-tab) URL="cloude://tab?type=chat" ;;
    files-tab) URL="cloude://tab?type=files" ;;
    git-tab) URL="cloude://tab?type=gitChanges" ;;
    *) URL="$ROUTE" ;;
esac

xcrun simctl openurl "$DEVICE_ID" "$URL"
