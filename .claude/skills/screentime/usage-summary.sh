#!/bin/bash
DB="$HOME/Library/Application Support/Knowledge/knowledgeC.db"

if [ ! -f "$DB" ]; then
    echo "ERROR: knowledgeC.db not found at $DB"
    exit 1
fi

MAC_EPOCH=978307200
NUM_DAYS="${1:-7}"

RANGE_START=$(date -v-"${NUM_DAYS}"d -v0H -v0M -v0S +%s)
RANGE_START_MAC=$((RANGE_START - MAC_EPOCH))

echo "Screen time summary (last $NUM_DAYS days)"
echo "---"

sqlite3 -separator '|' "$DB" "
WITH daily_usage AS (
    SELECT
        DATE(ZSTARTDATE + $MAC_EPOCH, 'UNIXEPOCH', 'LOCALTIME') AS usage_date,
        CASE
            WHEN ZVALUESTRING LIKE 'com.apple.Safari' THEN 'Safari'
            WHEN ZVALUESTRING LIKE 'com.apple.mail' THEN 'Mail'
            WHEN ZVALUESTRING LIKE 'com.apple.MobileSMS' THEN 'Messages'
            WHEN ZVALUESTRING LIKE 'com.apple.iCal' THEN 'Calendar'
            WHEN ZVALUESTRING LIKE 'com.apple.finder' THEN 'Finder'
            WHEN ZVALUESTRING LIKE 'com.apple.Terminal' THEN 'Terminal'
            WHEN ZVALUESTRING LIKE 'com.apple.dt.Xcode' THEN 'Xcode'
            WHEN ZVALUESTRING LIKE 'com.apple.Notes' THEN 'Notes'
            WHEN ZVALUESTRING LIKE 'com.apple.Music' THEN 'Music'
            WHEN ZVALUESTRING LIKE 'com.apple.Photos' THEN 'Photos'
            WHEN ZVALUESTRING LIKE 'com.apple.Preview' THEN 'Preview'
            WHEN ZVALUESTRING LIKE 'com.apple.systempreferences' THEN 'System Settings'
            WHEN ZVALUESTRING LIKE 'com.google.Chrome' THEN 'Chrome'
            WHEN ZVALUESTRING LIKE 'com.google.Chrome.canary' THEN 'Chrome Canary'
            WHEN ZVALUESTRING LIKE 'com.microsoft.VSCode' THEN 'VS Code'
            WHEN ZVALUESTRING LIKE 'com.microsoft.teams%' THEN 'Teams'
            WHEN ZVALUESTRING LIKE 'com.microsoft.Word' THEN 'Word'
            WHEN ZVALUESTRING LIKE 'com.microsoft.Excel' THEN 'Excel'
            WHEN ZVALUESTRING LIKE 'com.microsoft.Outlook' THEN 'Outlook'
            WHEN ZVALUESTRING LIKE 'com.tinyspeck.slackmacgap' THEN 'Slack'
            WHEN ZVALUESTRING LIKE 'com.spotify.client' THEN 'Spotify'
            WHEN ZVALUESTRING LIKE 'com.openai.chat' THEN 'ChatGPT'
            WHEN ZVALUESTRING LIKE 'com.linear' THEN 'Linear'
            WHEN ZVALUESTRING LIKE 'com.figma.Desktop' THEN 'Figma'
            WHEN ZVALUESTRING LIKE 'com.notion.Notion' THEN 'Notion'
            WHEN ZVALUESTRING LIKE 'com.hnc.Discord' THEN 'Discord'
            WHEN ZVALUESTRING LIKE 'com.raycast.macos' THEN 'Raycast'
            WHEN ZVALUESTRING LIKE 'com.anthropic.claudecode%' THEN 'Claude Code'
            WHEN ZVALUESTRING LIKE 'com.mitchellh.ghostty' THEN 'Ghostty'
            WHEN ZVALUESTRING LIKE 'com.googlecode.iterm2' THEN 'iTerm2'
            WHEN ZVALUESTRING LIKE 'ru.keepcoder.Telegram' THEN 'Telegram'
            WHEN ZVALUESTRING LIKE 'net.whatsapp.WhatsApp' THEN 'WhatsApp'
            WHEN ZVALUESTRING LIKE 'com.apple.%' THEN REPLACE(REPLACE(ZVALUESTRING, 'com.apple.', ''), '.', ' ')
            WHEN ZVALUESTRING LIKE 'com.%.%' THEN REPLACE(SUBSTR(ZVALUESTRING, INSTR(SUBSTR(ZVALUESTRING, INSTR(ZVALUESTRING, '.') + 1), '.') + INSTR(ZVALUESTRING, '.') + 1), '.', ' ')
            ELSE ZVALUESTRING
        END AS app_name,
        CASE
            WHEN ZENDDATE IS NOT NULL AND ZENDDATE > ZSTARTDATE
            THEN (ZENDDATE - ZSTARTDATE)
            ELSE 0
        END AS duration_secs
    FROM ZOBJECT
    WHERE ZSTREAMNAME = '/app/usage'
        AND ZSTARTDATE >= $RANGE_START_MAC
        AND ZVALUESTRING IS NOT NULL
),
per_day AS (
    SELECT
        usage_date,
        CAST(ROUND(SUM(duration_secs) / 60.0) AS INTEGER) AS total_minutes,
        app_name,
        CAST(ROUND(SUM(duration_secs) / 60.0) AS INTEGER) AS app_minutes
    FROM daily_usage
    GROUP BY usage_date, app_name
),
top_apps AS (
    SELECT
        usage_date,
        app_name,
        app_minutes,
        ROW_NUMBER() OVER (PARTITION BY usage_date ORDER BY app_minutes DESC) AS rn
    FROM per_day
),
day_totals AS (
    SELECT
        usage_date,
        SUM(app_minutes) AS total_minutes
    FROM per_day
    GROUP BY usage_date
)
SELECT
    d.usage_date,
    d.total_minutes,
    t.app_name || ' (' || t.app_minutes || 'min)'
FROM day_totals d
JOIN top_apps t ON d.usage_date = t.usage_date AND t.rn = 1
ORDER BY d.usage_date DESC;
" 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: Could not read knowledgeC.db. Ensure Full Disk Access is granted."
    exit 1
fi
