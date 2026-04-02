---
name: deploy
description: Deploy Cloude to TestFlight, install to iPhone, and build the Mac agent.
user-invocable: true
metadata:
  icon: airplane.departure
  aliases: [distribute, ship, release]
argument-hint: "[--mac-only|--ios-only|--phone]"
---

# Deploy

Deploy Cloude with scripts, not manual commands.

## Flags

- `/deploy`: auto-detect or deploy both when in doubt
- `/deploy --mac-only`: Mac agent only
- `/deploy --ios-only`: iOS only
- `/deploy --phone`: direct-to-phone install only

## Detect Scope

Check git status and changed files:
- `Cloude/Cloude Agent/` or `Cloude/CloudeShared/` means Mac agent changed
- `Cloude/Cloude/` or `Cloude/CloudeShared/` means iOS changed
- if the agent is not running, build and launch it

## Required Commands

iOS:
```bash
.claude/skills/deploy/deploy-ios.sh
```

Phone only:
```bash
.claude/skills/deploy/deploy-ios.sh --phone-only
```

Mac agent:
```bash
set -a && source .env && set +a && fastlane mac build_agent
```


## Workflow

1. Determine whether to deploy Mac, iOS, or both.
2. Run the script(s), never manual deploy steps.
3. Stop on failure.
4. Report the build number with `cd Cloude && agvtool what-version -terse`.
5. Tag untagged plans in `.claude/plans/30_testing/` with the build number.
6. Update deploy tracking in `CLAUDE.local.md`.

## Rules

- When in doubt, deploy both.
- Every deploy needs corresponding testing plans.
- If the user only wants local investigation, use `agentic-testing` instead.
