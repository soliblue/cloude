#!/bin/bash
SEARCH="${1:-}"
LIMIT="${2:-20}"
HISTORY_DB="$HOME/Library/Safari/History.db"

if [ ! -r "$HISTORY_DB" ]; then
    echo "ERROR: Cannot read $HISTORY_DB"
    echo "Grant Full Disk Access to Terminal: System Settings -> Privacy & Security -> Full Disk Access"
    exit 1
fi

if [ -n "$SEARCH" ]; then
    QUERY="SELECT datetime(v.visit_time + 978307200, 'unixepoch', 'localtime') as date, i.url, COALESCE(v.title, i.url) as title FROM history_visits v JOIN history_items i ON v.history_item = i.id WHERE (lower(v.title) LIKE lower('%${SEARCH}%') OR lower(i.url) LIKE lower('%${SEARCH}%')) ORDER BY v.visit_time DESC LIMIT ${LIMIT}"
else
    QUERY="SELECT datetime(v.visit_time + 978307200, 'unixepoch', 'localtime') as date, i.url, COALESCE(v.title, i.url) as title FROM history_visits v JOIN history_items i ON v.history_item = i.id ORDER BY v.visit_time DESC LIMIT ${LIMIT}"
fi

RESULT=$(sqlite3 -separator '|' "$HISTORY_DB" "$QUERY" 2>&1)

if [ -z "$RESULT" ]; then
    if [ -n "$SEARCH" ]; then
        echo "No history matching '$SEARCH'"
    else
        echo "No history found"
    fi
    exit 0
fi

echo "$RESULT" | while IFS='|' read -r date url title; do
    echo "${date}|${title}|${url}"
done
