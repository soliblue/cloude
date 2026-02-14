#!/bin/bash
LIMIT="${1:-10}"

osascript - "$LIMIT" <<'EOF'
on run argv
    set photoLimit to item 1 of argv as integer

    tell application "Photos"
        set allPhotos to media items
        set total to count of allPhotos
        set startIdx to total - photoLimit + 1
        if startIdx < 1 then set startIdx to 1

        set output to ""
        repeat with i from total to startIdx by -1
            set p to item i of allPhotos
            set pID to id of p
            set pName to filename of p
            set pDate to date of p
            set pWidth to width of p
            set pHeight to height of p
            set output to output & pID & "|" & pName & "|" & pDate & "|" & pWidth & "x" & pHeight & linefeed
        end repeat

        return output
    end tell
end run
EOF
