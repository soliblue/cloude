#!/bin/bash
DATA_DIR="$(dirname "$0")/data"
mkdir -p "$DATA_DIR"

FOLDER_FILTER="$1"

FOLDERS=$(osascript -e 'tell application "Notes" to get name of every folder')
IFS=', ' read -ra FOLDER_ARRAY <<< "$FOLDERS"

TOTAL=0
for FOLDER in "${FOLDER_ARRAY[@]}"; do
    if [ -n "$FOLDER_FILTER" ] && [ "$FOLDER" != "$FOLDER_FILTER" ]; then
        continue
    fi

    FOLDER_DIR="$DATA_DIR/$FOLDER"
    mkdir -p "$FOLDER_DIR"

    COUNT=$(osascript -e "tell application \"Notes\" to get count of notes of folder \"$FOLDER\"")
    echo "Exporting $FOLDER ($COUNT notes)..."

    osascript <<APPLESCRIPT
tell application "Notes"
    set noteList to notes of folder "$FOLDER"
    set total to count of noteList
    repeat with i from 1 to total
        set n to item i of noteList
        set noteTitle to name of n
        set noteBody to plaintext of n
        set noteDate to creation date of n
        set modDate to modification date of n

        set safeTitle to do shell script "echo " & quoted form of noteTitle & " | sed 's/[^a-zA-Z0-9 _-]//g' | sed 's/  */ /g' | head -c 100"
        set fileName to safeTitle & ".md"

        set dateStr to (year of noteDate as string) & "-"
        set m to (month of noteDate as integer)
        if m < 10 then set dateStr to dateStr & "0"
        set dateStr to dateStr & (m as string) & "-"
        set d to (day of noteDate as integer)
        if d < 10 then set dateStr to dateStr & "0"
        set dateStr to dateStr & (d as string)

        set modDateStr to (year of modDate as string) & "-"
        set mm to (month of modDate as integer)
        if mm < 10 then set modDateStr to modDateStr & "0"
        set modDateStr to modDateStr & (mm as string) & "-"
        set md to (day of modDate as integer)
        if md < 10 then set modDateStr to modDateStr & "0"
        set modDateStr to modDateStr & (md as string)

        set header to "---" & linefeed & "title: " & noteTitle & linefeed & "created: " & dateStr & linefeed & "modified: " & modDateStr & linefeed & "folder: $FOLDER" & linefeed & "---" & linefeed & linefeed

        set filePath to "$FOLDER_DIR/" & fileName
        do shell script "cat > " & quoted form of filePath & " <<'ENDOFNOTE'" & linefeed & header & noteBody & linefeed & "ENDOFNOTE"

        if i mod 10 = 0 then
            do shell script "echo '  " & i & "/" & total & "'"
        end if
    end repeat
end tell
APPLESCRIPT

    EXPORTED=$(ls "$FOLDER_DIR" | wc -l | tr -d ' ')
    TOTAL=$((TOTAL + EXPORTED))
    echo "  Done: $EXPORTED files in $FOLDER_DIR"
done

echo ""
echo "Export complete: $TOTAL notes total"
