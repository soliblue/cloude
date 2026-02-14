#!/bin/bash
QUERY="${1:?Usage: contact-search.sh <name_or_company>}"

osascript - "$QUERY" <<'EOF'
on run argv
    set query to item 1 of argv

    tell application "Contacts"
        set output to ""
        set matches to every person whose name contains query
        if (count of matches) is 0 then
            set matches to every person whose organization contains query
        end if

        repeat with p in matches
            set pName to name of p
            set pPhone to ""
            try
                set pPhone to value of first phone of p
            end try
            set pEmail to ""
            try
                set pEmail to value of first email of p
            end try
            set pCompany to ""
            try
                set pCompany to organization of p
                if pCompany is missing value then set pCompany to ""
            end try
            set output to output & pName & "|" & pPhone & "|" & pEmail & "|" & pCompany & linefeed
        end repeat

        if output is "" then
            return "No contacts matching '" & query & "'"
        end if
        return output
    end tell
end run
EOF
