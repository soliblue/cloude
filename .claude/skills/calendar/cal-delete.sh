#!/bin/bash
EVENT_UID="${1:?Usage: cal-delete.sh <event_uid> [calendar_name]}"
CALENDAR_FILTER="${2:-}"

osascript - "$EVENT_UID" "$CALENDAR_FILTER" <<'EOF'
on run argv
    set targetUID to item 1 of argv
    set calFilter to item 2 of argv

    tell application "Calendar"
        repeat with c in calendars
            if calFilter is "" or name of c is calFilter then
                try
                    set evts to (every event of c whose uid is targetUID)
                    repeat with e in evts
                        set eventName to summary of e
                        delete e
                        return "Deleted: " & eventName
                    end repeat
                end try
            end if
        end repeat
        return "ERROR: Event with UID '" & targetUID & "' not found"
    end tell
end run
EOF
