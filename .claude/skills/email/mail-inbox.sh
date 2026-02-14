#!/bin/bash
LIMIT="${1:-10}"
ACCOUNT_FILTER="${2:-}"

osascript - "$LIMIT" "$ACCOUNT_FILTER" <<'EOF'
on run argv
    set msgLimit to item 1 of argv as integer
    set acctFilter to item 2 of argv

    tell application "Mail"
        set output to ""
        set count_ to 0

        if acctFilter is "" then
            set msgs to messages of inbox
        else
            set targetAcct to missing value
            repeat with a in accounts
                if name of a is acctFilter then
                    set targetAcct to a
                    exit repeat
                end if
            end repeat
            if targetAcct is missing value then
                return "ERROR: Account '" & acctFilter & "' not found"
            end if
            set msgs to messages of inbox of targetAcct
        end if

        repeat with m in msgs
            if count_ ≥ msgLimit then exit repeat
            if read status of m is false then
                set mID to id of m
                set mFrom to sender of m
                set mSubject to subject of m
                set mDate to date received of m
                set output to output & mID & "|" & mFrom & "|" & mSubject & "|" & mDate & "|unread" & linefeed
                set count_ to count_ + 1
            end if
        end repeat

        if output is "" then
            return "No unread messages"
        end if
        return output
    end tell
end run
EOF
