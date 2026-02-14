#!/bin/bash
BOOKMARKS_PLIST="$HOME/Library/Safari/Bookmarks.plist"

if [ ! -r "$BOOKMARKS_PLIST" ]; then
    echo "ERROR: Cannot read $BOOKMARKS_PLIST"
    echo "Grant Full Disk Access to Terminal: System Settings -> Privacy & Security -> Full Disk Access"
    exit 1
fi

TMPFILE=$(mktemp /tmp/safari-readinglist.XXXXXX.xml)
trap "rm -f $TMPFILE" EXIT

plutil -convert xml1 -o "$TMPFILE" "$BOOKMARKS_PLIST" 2>/dev/null

if [ ! -s "$TMPFILE" ]; then
    echo "ERROR: Failed to convert bookmarks plist"
    exit 1
fi

osascript - "$TMPFILE" <<'APPLESCRIPT'
on run argv
    set plistPath to item 1 of argv
    set output to ""

    tell application "System Events"
        set plistFile to property list file plistPath
        set topChildren to value of property list item "Children" of plistFile

        repeat with child in topChildren
            set folderTitle to ""
            try
                set folderTitle to |Title| of child
            end try

            if folderTitle is "com.apple.ReadingList" then
                try
                    set rlChildren to |Children| of child
                on error
                    return "Reading list is empty"
                end try

                repeat with rlItem in rlChildren
                    set bmTitle to ""
                    set bmURL to ""
                    set bmDate to ""
                    set bmUnread to "yes"

                    try
                        set uriDict to |URIDictionary| of rlItem
                        set bmTitle to title of uriDict
                    end try
                    try
                        set bmURL to |URLString| of rlItem
                    end try
                    try
                        set readingList to |ReadingList| of rlItem
                        try
                            set bmDate to |DateAdded| of readingList
                        end try
                        try
                            set didRead to |DidRead| of readingList
                            if didRead then set bmUnread to "no"
                        end try
                    end try

                    if bmTitle is not "" and bmURL is not "" then
                        set output to output & bmTitle & "|" & bmURL & "|" & bmDate & "|" & bmUnread & linefeed
                    end if
                end repeat
            end if
        end repeat
    end tell

    if output is "" then return "No reading list items found"
    return output
end run
APPLESCRIPT
