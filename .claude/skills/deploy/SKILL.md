---
name: deploy
description: Deploy Cloude to TestFlight, install to iPhone, and build the Mac agent. Use when pushing changes and deploying, or when asked to "deploy", "push and deploy", "send to TestFlight", "install to phone", "deploy to iPhone", "wireless install", or "direct install".
user-invocable: true
icon: airplane.departure
aliases: [distribute, ship, release]
argument-hint: "[--mac-only|--ios-only|--phone]"
---

# Deploy Skill

Smart deployment workflow for Cloude. Deploys only what has changes (or everything if in doubt).

## Flags

- `/deploy` — auto-detect what changed and deploy accordingly
- `/deploy --mac-only` — force Mac agent build only (skip TestFlight)
- `/deploy --ios-only` — force iOS TestFlight build only (skip Mac agent)
- `/deploy --phone` — force direct-to-phone install (skip TestFlight)

When a flag is provided, skip the auto-detection logic and deploy the specified component directly.

## Pre-Deployment Checklist

**CRITICAL: This is a PUBLIC repo. Before committing, review for:**
- API keys, tokens, secrets, passwords
- `.env` files or their contents
- Personal information, private URLs
- Keychain data, auth tokens

If unsure about any file, ASK before committing.

## Determine What Needs Deployment

### 1. Check Git Status

```bash
git status
git diff --stat
```

### 2. Check What Changed

Look at the modified files to determine what needs deployment:

- **Mac Agent changes**: Files in `Cloude/Cloude Agent/` or `Cloude/CloudeShared/`
- **iOS App changes**: Files in `Cloude/Cloude/` or `Cloude/CloudeShared/`
- **Both**: If CloudeShared changed, both need deployment

### 3. Check if Mac Agent is Running

```bash
ps aux | grep -c "[C]loude Agent.app" | xargs -I{} test {} -gt 0 && echo "Agent running" || echo "Agent NOT running"
```

If the agent is not running, always build and launch it.

## Deployment Logic

| Agent Changed | iOS Changed | Agent Running | Action |
|---------------|-------------|---------------|--------|
| Yes | Yes | - | Deploy both |
| Yes | No | - | Mac agent only |
| No | Yes | Yes | iOS only |
| No | Yes | No | Both (agent needs starting) |
| No | No | Yes | Nothing to deploy |
| No | No | No | Mac agent only (to start it) |
| User asks "deploy" | - | - | Both (when in doubt) |

## CRITICAL: Use Scripts, Not Manual Commands

**NEVER execute manual deploy commands. ALWAYS use the scripts below.**

This ensures deterministic execution — no skipped steps, no placeholders, no variance.

- **iOS deployment**: `.claude/skills/deploy/deploy-ios.sh`
- **Mac agent**: Must be launched via `osascript` in a new Terminal window (see below)
- **Both**: Git push, then run both scripts

If a script fails, report the error and stop. Do not attempt manual commands.

## CRITICAL: Mac Agent Build Must Run in Separate Terminal

Claude Code cannot spawn inside another Claude Code session. Since the Mac agent build kills the running agent (which hosts this Claude Code process), you MUST launch it in a separate Terminal window using `osascript`:

```bash
osascript -e 'tell application "Terminal" to do script "cd $(git rev-parse --show-toplevel) && source .env && fastlane mac build_agent"'
```

**NEVER run `fastlane mac build_agent` directly** — it will either fail or kill your own session.

## Deployment Steps

### 1. Git Push (if changes exist)

```bash
git add .
git commit -m "$(cat <<'EOF'
feat: Short description of changes

- Bullet point details if needed

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
git push
```

### 2. iOS Deploy: Use the Script

**ALWAYS use the deploy script. NEVER run manual commands.**

```bash
.claude/skills/deploy/deploy-ios.sh
```

The script automatically:
- Checks if iPhone is connected (USB or Wi-Fi)
- Extracts device UUID if connected
- Installs directly to iPhone if connected
- Falls back to TestFlight if not connected
- Exits with error on failure (fail closed)

**Optional flag:**
```bash
.claude/skills/deploy/deploy-ios.sh --phone-only
```
Fails if phone is not connected (no TestFlight fallback).

### 3. Deploy Based on What Changed

**Both (default when in doubt):**
```bash
# Git push first, then deploy both
osascript -e 'tell application "Terminal" to do script "cd $(git rev-parse --show-toplevel) && source .env && fastlane mac build_agent"'
.claude/skills/deploy/deploy-ios.sh
```

**Mac agent only:**
```bash
osascript -e 'tell application "Terminal" to do script "cd $(git rev-parse --show-toplevel) && source .env && fastlane mac build_agent"'
```

**iOS only:**
```bash
.claude/skills/deploy/deploy-ios.sh
```

**Phone-only (fail if not connected):**
```bash
.claude/skills/deploy/deploy-ios.sh --phone-only
```

## Post-Deployment

### 1. Report Build Number (REQUIRED)

Always extract and report the build number after successful deploy:

```bash
cd Cloude && agvtool what-version -terse
```

Report it clearly: "Deployed Build XX to TestFlight" or "Installed Build XX directly to iPhone"

### 2. Tag Testing Plans with Build Number (REQUIRED)

Stamp all plans in `plans/30_testing/` that don't already have a `<!-- build: -->` tag with the current build number. This records which build a feature shipped in for testing. Plans move to `done/` independently when the user confirms they work — NOT at deploy time.

```bash
python3 -c "
import os, glob
build = os.popen('cd Cloude && agvtool what-version -terse').read().strip()
tagged = []
for f in glob.glob('plans/30_testing/*.md'):
    with open(f) as fh:
        content = fh.read()
    if '<!-- build:' not in content:
        title = content.split('\n')[0].lstrip('# ').strip()
        lines = content.split('\n')
        lines.insert(1, '<!-- build: ' + build + ' -->')
        with open(f, 'w') as fh:
            fh.write('\n'.join(lines))
        tagged.append(title)
print(f'Tagged {len(tagged)} testing plans with Build {build}')
if tagged:
    print('Plans in this deploy:')
    for t in tagged:
        print(f'  - {t}')
"
```

After the script runs, **include the plan titles in your deploy summary** so the user can see exactly what's shipping. Example:

> Deployed Build 66. Plans in this deploy:
> - Tool Pill Compact Spacing
> - CSV Header Padding Fix

### 3. Update Tracking (REQUIRED)

After successful deploy, update ALL of these:
1. Update "Last deploy" line in CLAUDE.local.md Notes section with date, build number, and brief description
2. Ensure any features just deployed have a corresponding plan in `plans/30_testing/` (the source of truth for what needs testing)

## How Deploy Works (Mac Agent Restart)

The `fastlane deploy` (or `fastlane mac build_agent`) handles the full cycle:
1. Builds the agent via xcodebuild
2. Kills the old agent with `pkill -9` (SIGKILL for instant termination)
3. Waits 3 seconds for the port to be released
4. Launches the new agent via `open`

The WebSocket server has built-in retry logic — if port 8765 is still in use, it retries up to 5 times with increasing delays (2s, 4s, 6s, 8s, 10s). This means deploying both Mac agent + iOS together is safe and reliable.

## Important Notes

- **CRITICAL**: Mac agent builds MUST use the `osascript` Terminal approach — never run fastlane mac build_agent directly
- **Deploying both is the default** — run osascript for agent + deploy script for iOS
- Always prefix fastlane commands with `source .env &&` to load API credentials
- Get confirmation before pushing to git
- If iOS signing fails, check App Store Connect certificates
