# Input Bar Autocomplete History
<!-- build: 86 -->

- Autocomplete suggestions based on previously sent messages
- Local/on-device storage via UserDefaults for instant speed
- Only saves messages under 50 chars, skips slash commands
- Shows matching suggestions as horizontal pills above the input bar
- Tapping a suggestion fills the input field
- Keeps last 50 unique messages, deduplicates case-insensitively
