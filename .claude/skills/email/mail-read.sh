#!/bin/bash
MESSAGE_ID="${1:?Usage: mail-read.sh <message_id>}"

osascript - "$MESSAGE_ID" <<'EOF'
on run argv
    set targetID to item 1 of argv as integer

    tell application "Mail"
        set targetMsg to missing value

        repeat with a in accounts
            repeat with mb in mailboxes of a
                try
                    set msgs to (every message of mb whose id is targetID)
                    if (count of msgs) > 0 then
                        set targetMsg to item 1 of msgs
                        exit repeat
                    end if
                end try
            end repeat
            if targetMsg is not missing value then exit repeat
        end repeat

        -- also check inbox directly
        if targetMsg is missing value then
            try
                set msgs to (every message of inbox whose id is targetID)
                if (count of msgs) > 0 then
                    set targetMsg to item 1 of msgs
                end if
            end try
        end if

        if targetMsg is missing value then
            return "ERROR: Message with ID " & targetID & " not found"
        end if

        set mFrom to sender of targetMsg
        set mTo to address of to recipients of targetMsg
        set mSubject to subject of targetMsg
        set mDate to date received of targetMsg
        set mContent to content of targetMsg

        -- truncate very long emails to avoid context window bloat
        if length of mContent > 10000 then
            set mContent to text 1 thru 10000 of mContent & linefeed & "[TRUNCATED — email exceeds 10,000 characters]"
        end if

        return "From: " & mFrom & linefeed & "To: " & mTo & linefeed & "Subject: " & mSubject & linefeed & "Date: " & mDate & linefeed & "---" & linefeed & mContent
    end tell
end run
EOF
