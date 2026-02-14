#!/bin/bash
osascript <<'EOF'
tell application "Photos"
    set output to ""
    repeat with a in albums
        set photoCount to count of media items of a
        set output to output & name of a & "|" & photoCount & " photos" & linefeed
    end repeat
    if output is "" then
        return "No albums found"
    end if
    return output
end tell
EOF
