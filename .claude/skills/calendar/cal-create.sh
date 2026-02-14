#!/bin/bash
CALENDAR="${1:?Usage: cal-create.sh <calendar> <title> <start> <end> [location] [notes] [allday]}"
TITLE="${2:?Missing title}"
START="${3:?Missing start date (YYYY-MM-DD HH:MM or YYYY-MM-DD)}"
END="${4:-}"
LOCATION="${5:-}"
NOTES="${6:-}"
ALLDAY="${7:-}"

osascript - "$CALENDAR" "$TITLE" "$START" "$END" "$LOCATION" "$NOTES" "$ALLDAY" <<'EOF'
on run argv
    set calName to item 1 of argv
    set eventTitle to item 2 of argv
    set startStr to item 3 of argv
    set endStr to item 4 of argv
    set loc to item 5 of argv
    set eventNotes to item 6 of argv
    set isAllDay to item 7 of argv

    tell application "Calendar"
        set targetCal to missing value
        repeat with c in calendars
            if name of c is calName then
                set targetCal to c
                exit repeat
            end if
        end repeat

        if targetCal is missing value then
            return "ERROR: Calendar '" & calName & "' not found"
        end if

        if isAllDay is "allday" then
            set startDate to date startStr
            set endDate to startDate + (1 * days)
            set newEvent to make new event at end of events of targetCal with properties {summary:eventTitle, start date:startDate, end date:endDate, allday event:true}
        else
            set startDate to date startStr
            if endStr is "" then
                set endDate to startDate + (1 * hours)
            else
                set endDate to date endStr
            end if
            set newEvent to make new event at end of events of targetCal with properties {summary:eventTitle, start date:startDate, end date:endDate}
        end if

        if loc is not "" then
            set location of newEvent to loc
        end if

        if eventNotes is not "" then
            set description of newEvent to eventNotes
        end if

        return "Created: " & eventTitle & " | " & startDate & " - " & endDate & " | " & uid of newEvent
    end tell
end run
EOF
