#!/bin/bash
LIMIT="${1:-5}"
ALBUM="${2:-}"
EXPORT_DIR="/tmp/cloude-photos"

mkdir -p "$EXPORT_DIR"
rm -f "$EXPORT_DIR"/*

osascript - "$LIMIT" "$ALBUM" "$EXPORT_DIR" <<'EOF'
on run argv
    set photoLimit to item 1 of argv as integer
    set albumName to item 2 of argv
    set exportDir to item 3 of argv

    tell application "Photos"
        if albumName is "" then
            set allPhotos to media items
            set total to count of allPhotos
            set startIdx to total - photoLimit + 1
            if startIdx < 1 then set startIdx to 1
            set targetPhotos to items startIdx thru total of allPhotos
        else
            set targetAlbum to missing value
            repeat with a in albums
                if name of a is albumName then
                    set targetAlbum to a
                    exit repeat
                end if
            end repeat
            if targetAlbum is missing value then
                return "ERROR: Album '" & albumName & "' not found"
            end if
            set allPhotos to media items of targetAlbum
            set total to count of allPhotos
            set startIdx to total - photoLimit + 1
            if startIdx < 1 then set startIdx to 1
            set targetPhotos to items startIdx thru total of allPhotos
        end if

        set exportFolder to POSIX file exportDir
        export targetPhotos to exportFolder

        return "Exported " & (count of targetPhotos) & " photos to " & exportDir
    end tell
end run
EOF
