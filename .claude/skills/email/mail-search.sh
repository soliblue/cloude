#!/bin/bash
QUERY="${1:?Usage: mail-search.sh <query> [limit] [account_name]}"
LIMIT="${2:-20}"
ACCOUNT_FILTER="${3:-}"

osascript - "$QUERY" "$LIMIT" "$ACCOUNT_FILTER" <<'EOF'
on run argv
    set query to item 1 of argv
    set msgLimit to item 2 of argv as integer
    set acctFilter to item 3 of argv

    tell application "Mail"
        set output to ""
        set count_ to 0

        repeat with a in accounts
            if acctFilter is not "" and name of a is not acctFilter then
                -- skip non-matching accounts
            else
                repeat with mb in {inbox of a}
                    try
                        set msgs to (every message of mb whose subject contains query or sender contains query)
                        repeat with m in msgs
                            if count_ ≥ msgLimit then exit repeat
                            set mID to id of m
                            set mFrom to sender of m
                            set mSubject to subject of m
                            set mDate to date received of m
                            set mRead to read status of m
                            set readStr to "read"
                            if mRead is false then set readStr to "unread"
                            set output to output & mID & "|" & mFrom & "|" & mSubject & "|" & mDate & "|" & readStr & "|" & name of a & linefeed
                            set count_ to count_ + 1
                        end repeat
                    end try
                    if count_ ≥ msgLimit then exit repeat
                end repeat
            end if
            if count_ ≥ msgLimit then exit repeat
        end repeat

        if output is "" then
            return "No messages matching '" & query & "'"
        end if
        return output
    end tell
end run
EOF
