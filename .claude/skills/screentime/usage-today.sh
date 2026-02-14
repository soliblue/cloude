#!/bin/bash
DB="$HOME/Library/Application Support/Knowledge/knowledgeC.db"

if [ ! -f "$DB" ]; then
    echo "ERROR: knowledgeC.db not found at $DB"
    exit 1
fi

MAC_EPOCH=978307200
TODAY_START=$(date -v0H -v0M -v0S +%s)
TODAY_START_MAC=$((TODAY_START - MAC_EPOCH))

sqlite3 -separator '|' "$DB" "
SELECT
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
        WHEN ZVALUESTRING LIKE 'com.apple.ActivityMonitor' THEN 'Activity Monitor'
        WHEN ZVALUESTRING LIKE 'com.apple.AppStore' THEN 'App Store'
        WHEN ZVALUESTRING LIKE 'com.apple.FaceTime' THEN 'FaceTime'
        WHEN ZVALUESTRING LIKE 'com.apple.reminders' THEN 'Reminders'
        WHEN ZVALUESTRING LIKE 'com.apple.Passwords' THEN 'Passwords'
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
        WHEN ZVALUESTRING LIKE 'com.freron.MailMate' THEN 'MailMate'
        WHEN ZVALUESTRING LIKE 'com.readdle.spark%' THEN 'Spark'
        WHEN ZVALUESTRING LIKE 'ru.keepcoder.Telegram' THEN 'Telegram'
        WHEN ZVALUESTRING LIKE 'com.atebits.Tweetie2' THEN 'Twitter'
        WHEN ZVALUESTRING LIKE 'net.whatsapp.WhatsApp' THEN 'WhatsApp'
        WHEN ZVALUESTRING LIKE 'com.1password%' THEN '1Password'
        WHEN ZVALUESTRING LIKE 'com.raycast.macos' THEN 'Raycast'
        WHEN ZVALUESTRING LIKE 'com.anthropic.claudecode%' THEN 'Claude Code'
        WHEN ZVALUESTRING LIKE 'com.mitchellh.ghostty' THEN 'Ghostty'
        WHEN ZVALUESTRING LIKE 'com.googlecode.iterm2' THEN 'iTerm2'
        WHEN ZVALUESTRING LIKE 'com.culturedcode.ThingsMac%' THEN 'Things'
        WHEN ZVALUESTRING LIKE 'com.todoist.mac.Todoist' THEN 'Todoist'
        WHEN ZVALUESTRING LIKE 'com.bohemiancoding.sketch3' THEN 'Sketch'
        WHEN ZVALUESTRING LIKE 'com.apple.%' THEN REPLACE(REPLACE(ZVALUESTRING, 'com.apple.', ''), '.', ' ')
        WHEN ZVALUESTRING LIKE 'com.%.%' THEN REPLACE(SUBSTR(ZVALUESTRING, INSTR(SUBSTR(ZVALUESTRING, INSTR(ZVALUESTRING, '.') + 1), '.') + INSTR(ZVALUESTRING, '.') + 1), '.', ' ')
        ELSE ZVALUESTRING
    END AS app_name,
    CAST(ROUND(SUM(
        CASE
            WHEN ZENDDATE IS NOT NULL AND ZENDDATE > ZSTARTDATE
            THEN MIN(ZENDDATE, CAST(strftime('%s', 'now') - $MAC_EPOCH AS REAL)) - MAX(ZSTARTDATE, $TODAY_START_MAC)
            ELSE 0
        END
    ) / 60.0) AS INTEGER) AS total_minutes
FROM ZOBJECT
WHERE ZSTREAMNAME = '/app/usage'
    AND ZSTARTDATE >= $TODAY_START_MAC
    AND ZVALUESTRING IS NOT NULL
GROUP BY ZVALUESTRING
HAVING total_minutes > 0
ORDER BY total_minutes DESC;
" 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: Could not read knowledgeC.db. Ensure Full Disk Access is granted."
    exit 1
fi
