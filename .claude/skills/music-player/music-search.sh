#!/bin/bash
QUERY="${1:?Usage: music-search.sh <query> [limit]}"
LIMIT="${2:-20}"

osascript - "$QUERY" "$LIMIT" <<'EOF'
on run argv
    set query to item 1 of argv
    set resultLimit to item 2 of argv as integer

    tell application "System Events"
        if not (exists process "Music") then
            tell application "Music" to activate
            delay 2
        end if
    end tell

    tell application "Music"
        set output to ""
        set matchCount to 0

        set nameMatches to (every track of library playlist 1 whose name contains query)
        repeat with t in nameMatches
            if matchCount >= resultLimit then exit repeat
            set dur to duration of t
            set mins to (dur div 60) as integer
            set secs to (dur mod 60) as integer
            if secs < 10 then
                set durStr to (mins as string) & ":0" & (secs as string)
            else
                set durStr to (mins as string) & ":" & (secs as string)
            end if
            set output to output & name of t & "|" & artist of t & "|" & album of t & "|" & durStr & linefeed
            set matchCount to matchCount + 1
        end repeat

        if matchCount < resultLimit then
            set artistMatches to (every track of library playlist 1 whose artist contains query)
            repeat with t in artistMatches
                if matchCount >= resultLimit then exit repeat
                set trackLine to name of t & "|" & artist of t & "|" & album of t
                if output does not contain trackLine then
                    set dur to duration of t
                    set mins to (dur div 60) as integer
                    set secs to (dur mod 60) as integer
                    if secs < 10 then
                        set durStr to (mins as string) & ":0" & (secs as string)
                    else
                        set durStr to (mins as string) & ":" & (secs as string)
                    end if
                    set output to output & trackLine & "|" & durStr & linefeed
                    set matchCount to matchCount + 1
                end if
            end repeat
        end if

        if matchCount < resultLimit then
            set albumMatches to (every track of library playlist 1 whose album contains query)
            repeat with t in albumMatches
                if matchCount >= resultLimit then exit repeat
                set trackLine to name of t & "|" & artist of t & "|" & album of t
                if output does not contain trackLine then
                    set dur to duration of t
                    set mins to (dur div 60) as integer
                    set secs to (dur mod 60) as integer
                    if secs < 10 then
                        set durStr to (mins as string) & ":0" & (secs as string)
                    else
                        set durStr to (mins as string) & ":" & (secs as string)
                    end if
                    set output to output & trackLine & "|" & durStr & linefeed
                    set matchCount to matchCount + 1
                end if
            end repeat
        end if

        if matchCount is 0 then
            return "No tracks found for: " & query
        end if

        return output
    end tell
end run
EOF
