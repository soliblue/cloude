---
name: deploy
description: Deploy Cloude to TestFlight and build the Mac agent. Use when pushing changes and deploying, or when asked to "deploy", "push and deploy", or "send to TestFlight".
user-invocable: true
icon: airplane.departure
aliases: [distribute, ship, release]
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

### 2. iOS Deploy: Check for Connected iPhone First

Before deploying iOS via TestFlight, check if My iPhone is connected (USB or Wi-Fi):

```bash
xcrun devicectl list devices 2>&1 | grep "My iPhone"
```

If the phone is **connected** (state = `connected`):
1. Build the app: `xcodebuild -project Cloude/Cloude.xcodeproj -scheme Cloude -destination "platform=iOS,name=My iPhone" build 2>&1 | tail -5`
2. Install directly: `xcrun devicectl device install app --device <DEVICE_UUID> /Users/soli/Library/Developer/Xcode/DerivedData/Cloude-drgeixundgtalkdkjnittevjxsyt/Build/Products/Debug-iphoneos/Cloude.app`
3. Report: "Installed directly to iPhone"

If the phone is **not connected** or `unavailable`:
1. Fall back to TestFlight: `source .env && fastlane ios beta_local`
2. If TestFlight fails with **upload limit error (409)** — Apple limits ~50-70 builds/day per app — tell Soli and suggest plugging in or enabling Wi-Fi debugging in Xcode to install directly next time.

### 3. Deploy Based on What Changed

**Both (default when in doubt):**
```bash
source .env && fastlane deploy
```
Note: For the iOS portion, still check for connected phone first (step 2 above). If phone is connected, use `fastlane mac build_agent` for the Mac side and direct install for iOS.

**Mac agent only:**
```bash
source .env && fastlane mac build_agent
```

**iOS only:**
Use the connected phone check from step 2 above. Direct install if connected, TestFlight if not.

## Post-Deployment

### 1. Report Build Number (REQUIRED)

Always extract and report the build number after successful deploy:

```bash
cd Cloude && agvtool what-version -terse
```

Report it clearly: "Deployed Build XX to TestFlight" or "Installed Build XX directly to iPhone"

### 2. Tag Testing Plans with Build Number (REQUIRED)

Stamp all plans in `plans/testing/` that don't already have a `<!-- build: -->` tag with the current build number. This records which build a feature shipped in for testing. Plans move to `done/` independently when Soli confirms they work — NOT at deploy time.

```bash
python3 -c "
import os, glob
build = os.popen('cd Cloude && agvtool what-version -terse').read().strip()
count = 0
for f in glob.glob('plans/testing/*.md'):
    with open(f) as fh:
        content = fh.read()
    if '<!-- build:' not in content:
        lines = content.split('\n')
        lines.insert(1, '<!-- build: ' + build + ' -->')
        with open(f, 'w') as fh:
            fh.write('\n'.join(lines))
        count += 1
print(f'Tagged {count} testing plans with Build {build}')
"
```

### 3. Update Tracking (REQUIRED)

After successful deploy, update ALL of these:
1. Update "Last deploy" line in CLAUDE.local.md Notes section with date, build number, and brief description
2. Ensure any features just deployed have a corresponding plan in `plans/testing/` (the source of truth for what needs testing)

## How Deploy Works (Mac Agent Restart)

The `fastlane deploy` (or `fastlane mac build_agent`) handles the full cycle:
1. Builds the agent via xcodebuild
2. Kills the old agent with `pkill -9` (SIGKILL for instant termination)
3. Waits 3 seconds for the port to be released
4. Launches the new agent via `open`

The WebSocket server has built-in retry logic — if port 8765 is still in use, it retries up to 5 times with increasing delays (2s, 4s, 6s, 8s, 10s). This means deploying both Mac agent + iOS together is safe and reliable.

## Important Notes

- **CRITICAL**: Always run the deployment command as the LAST thing in your response. The connection will drop briefly when the Mac agent restarts.
- **Deploying both is the default** — `fastlane deploy` handles Mac agent + iOS together safely
- Always prefix fastlane commands with `source .env &&` to load API credentials
- Get confirmation before pushing to git
- If iOS signing fails, check App Store Connect certificates
