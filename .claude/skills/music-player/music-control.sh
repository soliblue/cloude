#!/bin/bash
ACTION="${1:?Usage: music-control.sh <play|pause|toggle|next|previous|volume> [value]}"
VALUE="${2:-}"

osascript - "$ACTION" "$VALUE" <<'EOF'
on run argv
    set action to item 1 of argv
    set val to item 2 of argv

    tell application "System Events"
        if not (exists process "Music") then
            tell application "Music" to activate
            delay 2
        end if
    end tell

    tell application "Music"
        if action is "play" then
            play
            return "Playing"

        else if action is "pause" then
            pause
            return "Paused"

        else if action is "toggle" then
            if player state is playing then
                pause
                return "Paused"
            else
                play
                return "Playing"
            end if

        else if action is "next" then
            next track
            delay 0.5
            return "Next: " & name of current track & " - " & artist of current track

        else if action is "previous" then
            previous track
            delay 0.5
            return "Previous: " & name of current track & " - " & artist of current track

        else if action is "volume" then
            if val is "up" then
                set currentVol to sound volume
                set newVol to currentVol + 10
                if newVol > 100 then set newVol to 100
                set sound volume to newVol
                return "Volume: " & (newVol as string)

            else if val is "down" then
                set currentVol to sound volume
                set newVol to currentVol - 10
                if newVol < 0 then set newVol to 0
                set sound volume to newVol
                return "Volume: " & (newVol as string)

            else
                set newVol to val as integer
                if newVol < 0 then set newVol to 0
                if newVol > 100 then set newVol to 100
                set sound volume to newVol
                return "Volume: " & (newVol as string)
            end if

        else
            return "Unknown action: " & action & ". Use: play, pause, toggle, next, previous, volume"
        end if
    end tell
end run
EOF
