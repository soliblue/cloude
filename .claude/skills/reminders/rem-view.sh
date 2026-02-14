#!/bin/bash
LIST_FILTER="${1:-}"
SHOW_COMPLETED="${2:-}"

osascript - "$LIST_FILTER" "$SHOW_COMPLETED" <<'EOF'
on run argv
    set listFilter to item 1 of argv
    set showCompleted to item 2 of argv

    tell application "Reminders"
        set output to ""
        repeat with l in lists
            if listFilter is "" or name of l is listFilter then
                if showCompleted is "completed" then
                    set rems to (reminders of l whose completed is true)
                else
                    set rems to (reminders of l whose completed is false)
                end if
                repeat with r in rems
                    set rName to name of r
                    set rDue to ""
                    try
                        set d to due date of r
                        if d is not missing value then
                            set rDue to d as string
                        end if
                    end try
                    set rCompleted to completed of r
                    set rNotes to ""
                    try
                        set rNotes to body of r
                        if rNotes is missing value then set rNotes to ""
                    end try
                    set output to output & name of l & "|" & rName & "|" & rDue & "|" & rCompleted & "|" & rNotes & linefeed
                end repeat
            end if
        end repeat
        return output
    end tell
end run
EOF
