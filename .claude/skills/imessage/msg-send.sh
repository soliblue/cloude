#!/bin/bash
RECIPIENT="${1:?Usage: msg-send.sh <phone_or_email> \"message text\"}"
MESSAGE="${2:?Missing message text}"

SAFE_MESSAGE=$(echo "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g')

osascript <<EOF
tell application "Messages"
    set targetService to 1st account whose service type = iMessage
    set targetBuddy to participant "$RECIPIENT" of targetService
    send "$SAFE_MESSAGE" to targetBuddy
end tell
EOF

if [ $? -eq 0 ]; then
    echo "SENT: To $RECIPIENT"
else
    echo "ERROR: Failed to send. Check recipient format (phone with country code or email)."
    exit 1
fi
