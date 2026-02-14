#!/bin/bash
NAME="${1:?Usage: rem-complete.sh <reminder_name> [list_name]}"
LIST="${2:-}"

osascript - "$NAME" "$LIST" <<'EOF'
on run argv
    set remName to item 1 of argv
    set listFilter to item 2 of argv

    tell application "Reminders"
        repeat with l in lists
            if listFilter is "" or name of l is listFilter then
                set rems to (reminders of l whose name is remName and completed is false)
                repeat with r in rems
                    set completed of r to true
                    return "Completed: " & remName
                end repeat
            end if
        end repeat
        return "ERROR: Reminder '" & remName & "' not found (or already completed)"
    end tell
end run
EOF
