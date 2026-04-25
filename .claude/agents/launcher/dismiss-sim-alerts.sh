#!/bin/bash
set -euo pipefail

DURATION="${1:-15}"
END_TS=$(($(date +%s) + DURATION))

while (( $(date +%s) < END_TS )); do
  osascript <<'AS' >/dev/null 2>&1
tell application "System Events"
    if not (exists process "Simulator") then return
    tell process "Simulator"
        set frontmost to true
    end tell
    delay 0.25
    set frontProc to name of first application process whose frontmost is true
    if frontProc is not "Simulator" then return
    tell process "Simulator"
        repeat with w in every window
            try
                set p to position of w
                set s to size of w
                set wx to item 1 of p
                set wy to item 2 of p
                set ww to item 1 of s
                set wh to item 2 of s
                set cx to wx + (ww * 0.66)
                repeat with yFrac in {0.55, 0.60, 0.65, 0.45}
                    set cy to wy + (wh * yFrac)
                    try
                        click at {cx as integer, cy as integer}
                    end try
                end repeat
            end try
        end repeat
    end tell
end tell
AS
  sleep 0.5
done
