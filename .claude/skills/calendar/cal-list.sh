#!/bin/bash
osascript <<'EOF'
tell application "Calendar"
    set output to ""
    repeat with c in calendars
        set output to output & name of c & "|" & uid of c & linefeed
    end repeat
    return output
end tell
EOF
