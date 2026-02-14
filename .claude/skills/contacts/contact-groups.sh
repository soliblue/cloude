#!/bin/bash
osascript <<'EOF'
tell application "Contacts"
    set output to ""
    repeat with g in groups
        set memberCount to count of people of g
        set output to output & name of g & "|" & memberCount & " contacts" & linefeed
    end repeat
    if output is "" then
        return "No contact groups found"
    end if
    return output
end tell
EOF
