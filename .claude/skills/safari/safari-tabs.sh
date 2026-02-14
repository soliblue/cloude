#!/bin/bash
osascript <<'EOF'
tell application "Safari"
    set output to ""
    set winNum to 0
    repeat with w in windows
        set winNum to winNum + 1
        set tabNum to 0
        set activeIndex to index of current tab of w
        repeat with t in tabs of w
            set tabNum to tabNum + 1
            set isActive to "no"
            if tabNum is equal to activeIndex then set isActive to "yes"
            set tabTitle to name of t
            if tabTitle is missing value then set tabTitle to ""
            set tabURL to URL of t
            if tabURL is missing value then set tabURL to ""
            set output to output & winNum & "|" & tabNum & "|" & isActive & "|" & tabTitle & "|" & tabURL & linefeed
        end repeat
    end repeat
    if output is "" then return "No Safari windows open"
    return output
end tell
EOF
