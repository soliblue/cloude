#!/bin/bash
QUERY="${1:?Usage: cal-search.sh <query> [days_ahead] [calendar_name]}"
DAYS_AHEAD="${2:-30}"
CALENDAR_FILTER="${3:-}"

osascript - "$QUERY" "$DAYS_AHEAD" "$CALENDAR_FILTER" <<'EOF'
on run argv
    set query to item 1 of argv
    set daysAhead to item 2 of argv as integer
    set calFilter to item 3 of argv

    tell application "Calendar"
        set now to current date
        set endDate to now + (daysAhead * days)
        set output to ""

        repeat with c in calendars
            if calFilter is "" or name of c is calFilter then
                set evts to (every event of c whose start date ≥ now and start date ≤ endDate and summary contains query)
                repeat with e in evts
                    set eUID to uid of e
                    set eSummary to summary of e
                    set eStart to start date of e
                    set eEnd to end date of e
                    set eAllDay to allday event of e

                    set eLoc to ""
                    try
                        set eLoc to location of e
                        if eLoc is missing value then set eLoc to ""
                    end try

                    set output to output & eUID & "|" & eSummary & "|" & eStart & "|" & eEnd & "|" & eAllDay & "|" & eLoc & "|" & name of c & linefeed
                end repeat
            end if
        end repeat

        return output
    end tell
end run
EOF
