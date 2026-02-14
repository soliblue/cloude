#!/bin/bash
DATE="${1:?Usage: photos-by-date.sh <YYYY-MM-DD> [limit]}"
LIMIT="${2:-20}"

osascript - "$DATE" "$LIMIT" <<'EOF'
on run argv
    set targetDateStr to item 1 of argv
    set photoLimit to item 2 of argv as integer

    set targetDate to date targetDateStr
    set nextDay to targetDate + (1 * days)

    tell application "Photos"
        set matches to (media items whose date ≥ targetDate and date < nextDay)
        set total to count of matches
        if total > photoLimit then set total to photoLimit

        set output to ""
        repeat with i from 1 to total
            set p to item i of matches
            set pID to id of p
            set pName to filename of p
            set pDate to date of p
            set pWidth to width of p
            set pHeight to height of p
            set output to output & pID & "|" & pName & "|" & pDate & "|" & pWidth & "x" & pHeight & linefeed
        end repeat

        if output is "" then
            return "No photos found for " & targetDateStr
        end if
        return output
    end tell
end run
EOF
