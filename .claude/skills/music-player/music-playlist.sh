#!/bin/bash
PLAYLIST_NAME="${1:-}"

osascript - "$PLAYLIST_NAME" <<'EOF'
on run argv
    set playlistName to item 1 of argv

    tell application "System Events"
        if not (exists process "Music") then
            tell application "Music" to activate
            delay 2
        end if
    end tell

    tell application "Music"
        if playlistName is "" then
            set output to ""
            repeat with p in user playlists
                set pName to name of p
                set tCount to count of tracks of p
                set output to output & pName & "|" & (tCount as string) & linefeed
            end repeat
            if output is "" then
                return "No playlists found"
            end if
            return output

        else
            set targetPlaylist to missing value
            repeat with p in user playlists
                if name of p is playlistName then
                    set targetPlaylist to p
                    exit repeat
                end if
            end repeat

            if targetPlaylist is missing value then
                return "Playlist not found: " & playlistName
            end if

            set output to ""
            repeat with t in tracks of targetPlaylist
                set dur to duration of t
                set mins to (dur div 60) as integer
                set secs to (dur mod 60) as integer
                if secs < 10 then
                    set durStr to (mins as string) & ":0" & (secs as string)
                else
                    set durStr to (mins as string) & ":" & (secs as string)
                end if
                set output to output & name of t & "|" & artist of t & "|" & album of t & "|" & durStr & linefeed
            end repeat

            if output is "" then
                return "No tracks in playlist: " & playlistName
            end if
            return output
        end if
    end tell
end run
EOF
