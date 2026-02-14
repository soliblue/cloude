#!/bin/bash
osascript <<'EOF'
tell application "Reminders"
    set output to ""
    repeat with l in lists
        set rCount to count of (reminders of l whose completed is false)
        set output to output & name of l & "|" & rCount & " incomplete" & linefeed
    end repeat
    return output
end tell
EOF
