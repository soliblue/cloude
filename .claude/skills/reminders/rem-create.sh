#!/bin/bash
NAME="${1:?Usage: rem-create.sh <name> [list] [due_date] [notes]}"
LIST="${2:-Reminders}"
DUE_DATE="${3:-}"
NOTES="${4:-}"

osascript - "$NAME" "$LIST" "$DUE_DATE" "$NOTES" <<'EOF'
on run argv
    set remName to item 1 of argv
    set listName to item 2 of argv
    set dueStr to item 3 of argv
    set remNotes to item 4 of argv

    tell application "Reminders"
        set targetList to missing value
        repeat with l in lists
            if name of l is listName then
                set targetList to l
                exit repeat
            end if
        end repeat

        if targetList is missing value then
            return "ERROR: List '" & listName & "' not found"
        end if

        set props to {name:remName}

        if dueStr is not "" then
            set dueDate to date dueStr
            set props to props & {due date:dueDate}
        end if

        if remNotes is not "" then
            set props to props & {body:remNotes}
        end if

        set newRem to make new reminder at end of reminders of targetList with properties props
        return "Created: " & remName & " in " & listName
    end tell
end run
EOF
