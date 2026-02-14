#!/bin/bash
SEARCH="${1:-}"
BOOKMARKS_PLIST="$HOME/Library/Safari/Bookmarks.plist"

if [ ! -r "$BOOKMARKS_PLIST" ]; then
    echo "ERROR: Cannot read $BOOKMARKS_PLIST"
    echo "Grant Full Disk Access to Terminal: System Settings -> Privacy & Security -> Full Disk Access"
    exit 1
fi

TMPFILE=$(mktemp /tmp/safari-bookmarks.XXXXXX.xml)
trap "rm -f $TMPFILE" EXIT

plutil -convert xml1 -o "$TMPFILE" "$BOOKMARKS_PLIST" 2>/dev/null

if [ ! -s "$TMPFILE" ]; then
    echo "ERROR: Failed to convert bookmarks plist"
    exit 1
fi

osascript - "$TMPFILE" "$SEARCH" <<'APPLESCRIPT'
on run argv
    set plistPath to item 1 of argv
    set searchTerm to ""
    if (count of argv) > 1 then set searchTerm to item 2 of argv

    set output to ""

    tell application "System Events"
        set plistFile to property list file plistPath
        set topChildren to value of property list item "Children" of plistFile

        repeat with child in topChildren
            set folderTitle to ""
            try
                set folderTitle to |Title| of child
            end try
            if folderTitle is "BookmarksBar" then set folderTitle to "Favorites"
            if folderTitle is "BookmarksMenu" then set folderTitle to "Bookmarks Menu"

            set output to output & my processFolder(child, folderTitle, searchTerm)
        end repeat
    end tell

    if output is "" then
        if searchTerm is not "" then
            return "No bookmarks matching '" & searchTerm & "'"
        else
            return "No bookmarks found"
        end if
    end if
    return output
end run

on processFolder(folderDict, folderName, searchTerm)
    set result to ""
    try
        set children to |Children| of folderDict
    on error
        try
            set itemTitle to |URIDictionary| of folderDict
            set bmTitle to title of itemTitle
            set bmURL to |URLString| of folderDict
            if searchTerm is "" or bmTitle contains searchTerm or bmURL contains searchTerm then
                set result to result & bmTitle & "|" & bmURL & "|" & folderName & linefeed
            end if
        end try
        return result
    end try

    repeat with child in children
        set childType to ""
        try
            set childType to |WebBookmarkType| of child
        end try

        if childType is "WebBookmarkTypeLeaf" then
            try
                set itemTitle to |URIDictionary| of child
                set bmTitle to title of itemTitle
                set bmURL to |URLString| of child
                if searchTerm is "" or bmTitle contains searchTerm or bmURL contains searchTerm then
                    set result to result & bmTitle & "|" & bmURL & "|" & folderName & linefeed
                end if
            end try
        else if childType is "WebBookmarkTypeList" then
            set subFolderName to ""
            try
                set subFolderName to |Title| of child
            end try
            if subFolderName is "" then set subFolderName to folderName
            set result to result & my processFolder(child, subFolderName, searchTerm)
        end if
    end repeat
    return result
end processFolder
APPLESCRIPT
