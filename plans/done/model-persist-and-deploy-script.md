# Model Selection Persistence + Deploy Script

## Changes

### 1. Model selection persists across window switches
- Previously, switching windows with an empty input bar would lose your model selection (e.g. Opus → default)
- Fixed by always saving drafts on window switch, not just when input bar has text
- File: `MainChatView.swift` — removed conditional around draft saving

### 2. Deploy iOS script (`deploy-ios.sh`)
- Created `.claude/skills/deploy/deploy-ios.sh` — single script that handles all iOS deployment
- Automatically checks if iPhone is connected, extracts UUID, installs directly
- Falls back to TestFlight if phone not connected
- `--phone-only` flag to fail if phone not connected (no fallback)
- Updated deploy skill SKILL.md to mandate using the script instead of manual commands
- Added trigger keywords: "install to phone", "deploy to iPhone", "wireless install", "direct install"
