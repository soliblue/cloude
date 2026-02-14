#!/bin/bash
QUERY="${1:?Usage: contact-detail.sh <name>}"

osascript - "$QUERY" <<'EOF'
on run argv
    set query to item 1 of argv

    tell application "Contacts"
        set matches to every person whose name contains query
        if (count of matches) is 0 then
            return "No contact matching '" & query & "'"
        end if

        set p to item 1 of matches
        set output to "Name: " & name of p

        try
            set phones to value of every phone of p
            repeat with ph in phones
                set output to output & linefeed & "Phone: " & ph
            end repeat
        end try

        try
            set emails to value of every email of p
            repeat with em in emails
                set output to output & linefeed & "Email: " & em
            end repeat
        end try

        try
            set org to organization of p
            if org is not missing value then
                set output to output & linefeed & "Company: " & org
            end if
        end try

        try
            set bday to birth date of p
            if bday is not missing value then
                set output to output & linefeed & "Birthday: " & bday
            end if
        end try

        try
            repeat with addr in every address of p
                set addrStr to formatted address of addr
                set output to output & linefeed & "Address: " & addrStr
            end repeat
        end try

        try
            set n to note of p
            if n is not missing value and n is not "" then
                set output to output & linefeed & "Notes: " & n
            end if
        end try

        return output
    end tell
end run
EOF
