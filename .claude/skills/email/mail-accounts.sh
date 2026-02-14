#!/bin/bash
osascript <<'EOF'
tell application "Mail"
    set output to ""
    repeat with a in accounts
        set acctName to name of a
        set acctEmail to email addresses of a
        set acctEnabled to enabled of a
        set output to output & acctName & "|" & acctEmail & "|" & acctEnabled & linefeed
    end repeat
    return output
end tell
EOF
