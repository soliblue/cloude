---
name: deploy
description: Deploy Cloude to TestFlight and build the Mac agent. Use when pushing changes and deploying, or when asked to "deploy", "push and deploy", or "send to TestFlight".
user-invocable: true
icon: airplane.departure
aliases: [distribute, ship, release]
---

# Deploy Skill

Smart deployment workflow for Cloude. Deploys only what has changes (or everything if in doubt).

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

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
git push
```

### 2. Deploy Based on What Changed

**Both (default when in doubt):**
```bash
source .env && fastlane deploy
```

**Mac agent only:**
```bash
source .env && fastlane mac build_agent
```

**iOS only:**
```bash
source .env && fastlane ios beta_local
```

## Post-Deployment

### 1. Report Build Number (REQUIRED)

Always extract and report the build number after successful deploy:

```bash
cd Cloude && agvtool what-version -terse
```

Report it clearly: "Deployed Build XX to TestFlight"

### 2. Update Staging in CLAUDE.local.md

After successful deploy:
1. Update "Last deploy" timestamp with date and build number
2. Add build number to features that were just deployed

**Feature states:**
- `- Feature description` (no build number) = in development, not yet deployed
- `- Feature description (Build XX)` = deployed, awaiting test
- Delete from list = Soli confirmed it works

Items stay until Soli confirms they work. The build number tells you when it shipped.

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
