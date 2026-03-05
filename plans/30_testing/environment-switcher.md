# Environment Switcher
<!-- build: 82 -->

Swipeable card carousel in Settings to save and switch between multiple Mac agent connections (e.g., work machine + personal machine). Each environment gets a claude-on-clouds character avatar.

Step 1 only — credential switching. No conversation tagging or filtering yet.

## Changes
- `Environment.swift` — ServerEnvironment model
- `EnvironmentStore.swift` — persistence, migration from legacy credentials
- `SettingsView+Environments.swift` — card carousel UI
- `SettingsView.swift` — replaced old connection section
- `CloudeApp.swift` — wired EnvironmentStore into startup
- 7 claude-on-clouds character images added to xcassets
- Fixed REF_IMAGES bug in image generation script
