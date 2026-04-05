# Smoke Suite

Run this after any meaningful app change unless the scope is clearly narrower.

Always rebuild and relaunch the current local stack before running the suite unless the user explicitly asks for a log-only pass.

## Workflow

1. Rebuild and launch the stack.
2. Start log streaming.
3. Wait for `finish name=environment.auth ... success=true` in `app-debug.log`.
4. Open a fresh conversation rooted at the current working directory.
5. Switch the active conversation to `haiku` unless the test specifically targets model behavior.
6. Trigger the flow under test with deep links or a scenario.
7. Read app logs first.
8. Use screenshots or recordings only as secondary confirmation unless the behavior is inherently visual.

## Core Verification

### 1. Connection bootstrap

Pass criteria in `app-debug.log`:

- `connectEnvironment ...`
- `start name=environment.auth ...`
- `finish name=environment.auth ... success=true`

### 2. Long markdown streaming

```bash
.claude/skills/sim/scripts/send-simulator-message.sh "Write a long markdown answer with 8 sections, headings, bullet lists, and a short table about the architecture of this repo."
```

### 3. Tool-call streaming

Use `scenarios/mixed-markdown-multi-tool.txt`.

### 4. Streaming lifecycle stress

Use `scenarios/streaming-lifecycle-stress.md` for the highest-coverage multi-turn flow. This is the default stress case when a round touches reconnect, relaunch, follow-up messaging, or agent tool groups.

### 5. Abort and stop-run behavior

```bash
.claude/skills/sim/scripts/send-simulator-message.sh "Read the entire repo and write a detailed architecture summary with many citations."
.claude/skills/sim/scripts/open-simulator-url.sh stop-run
```

### 6. One file flow and one git flow

Suggested checks:

```bash
xcrun simctl openurl booted "cloude://file/Users/soli/Desktop/CODING/cloude/README.md"
xcrun simctl openurl booted "cloude://git?path=/Users/soli/Desktop/CODING/cloude"
xcrun simctl openurl booted "cloude://git/diff?path=/Users/soli/Desktop/CODING/cloude&file=Cloude/Cloude/Features/Workspace/Utils/WorkspaceActions.swift&staged=false"
```

### 7. Perf sanity

Inspect:

- `chat.firstToken`
- `chat.complete`
- `environment.auth`
- `debug sample fps=<n> owcPerSec=<n>`
