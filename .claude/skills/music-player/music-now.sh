#!/bin/bash
osascript <<'EOF'
tell application "System Events"
    if not (exists process "Music") then
        return "Music app is not running"
    end if
end tell

tell application "Music"
    set playerState to player state as string

    if playerState is "stopped" then
        return "State: stopped"
    end if

    set trackName to name of current track
    set trackArtist to artist of current track
    set trackAlbum to album of current track
    set trackDuration to duration of current track
    set playerPos to player position
    set vol to sound volume

    set totalMins to (trackDuration div 60) as integer
    set totalSecs to (trackDuration mod 60) as integer
    if totalSecs < 10 then
        set totalStr to (totalMins as string) & ":0" & (totalSecs as string)
    else
        set totalStr to (totalMins as string) & ":" & (totalSecs as string)
    end if

    set posMins to (playerPos div 60) as integer
    set posSecs to (playerPos mod 60) as integer
    if posSecs < 10 then
        set posStr to (posMins as string) & ":0" & (posSecs as string)
    else
        set posStr to (posMins as string) & ":" & (posSecs as string)
    end if

    set output to "State: " & playerState & linefeed
    set output to output & "Track: " & trackName & linefeed
    set output to output & "Artist: " & trackArtist & linefeed
    set output to output & "Album: " & trackAlbum & linefeed
    set output to output & "Position: " & posStr & " / " & totalStr & linefeed
    set output to output & "Volume: " & (vol as string)

    return output
end tell
EOF
