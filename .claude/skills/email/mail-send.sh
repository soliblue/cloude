#!/bin/bash
TO="${1:?Usage: mail-send.sh <to> <subject> <body> [send_now]}"
SUBJECT="${2:?Missing subject}"
BODY="${3:?Missing body}"
SEND_NOW="${4:-}"

osascript - "$TO" "$SUBJECT" "$BODY" "$SEND_NOW" <<'EOF'
on run argv
    set toAddr to item 1 of argv
    set subj to item 2 of argv
    set body_ to item 3 of argv
    set sendNow to item 4 of argv

    tell application "Mail"
        set newMsg to make new outgoing message with properties {subject:subj, content:body_, visible:true}
        tell newMsg
            make new to recipient at end of to recipients with properties {address:toAddr}
        end tell

        if sendNow is "send" then
            send newMsg
            return "SENT: To " & toAddr & " | Subject: " & subj
        else
            return "DRAFT CREATED: To " & toAddr & " | Subject: " & subj & " | Open Mail.app to review and send"
        end if
    end tell
end run
EOF
