#!/bin/bash
MODE="${1:-full}"
OUTPUT="/tmp/cloude-screenshot.png"

if [ "$MODE" = "window" ]; then
    FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')
    WINDOW_ID=$(osascript -e "tell application \"System Events\" to tell process \"$FRONT_APP\" to get id of window 1" 2>/dev/null)
    if [ -n "$WINDOW_ID" ]; then
        screencapture -x -l "$WINDOW_ID" "$OUTPUT" 2>&1
    else
        screencapture -x -w "$OUTPUT" 2>&1
    fi
else
    screencapture -x "$OUTPUT" 2>&1
fi

if [ -f "$OUTPUT" ]; then
    echo "$OUTPUT"
else
    echo "ERROR: Screenshot failed. Display may be asleep or screen recording permission not granted."
    exit 1
fi
