#!/bin/bash
QUERY="${1:?Usage: rem-search.sh <query>}"

osascript - "$QUERY" <<'EOF'
on run argv
    set query to item 1 of argv

    tell application "Reminders"
        set output to ""
        repeat with l in lists
            set rems to (reminders of l whose name contains query)
            repeat with r in rems
                set rDue to ""
                try
                    set d to due date of r
                    if d is not missing value then set rDue to d as string
                end try
                set rNotes to ""
                try
                    set rNotes to body of r
                    if rNotes is missing value then set rNotes to ""
                end try
                set output to output & name of l & "|" & name of r & "|" & rDue & "|" & completed of r & "|" & rNotes & linefeed
            end repeat
        end repeat
        return output
    end tell
end run
EOF
