---
name: agentic-testing
description: Build Cloude locally, launch it in Simulator, connect it to the local Mac agent, and inspect behavior through logs first and screenshots second.
user-invocable: true
metadata:
  icon: desktopcomputer.and.iphone
  aliases: [sim, simulator, local-test, agent-test]
argument-hint: "[--build|--logs|--open <route>|--send <text>]"
---

# Agentic Testing

Use this skill to rebuild the local stack, open Cloude in Simulator, and debug through logs first.

## Principles

- Prefer logs over screenshots.
- Prefer deterministic launch state over manual tapping.
- Prefer deep links over ad hoc navigation.
- Use screenshots only for visual confirmation.

## Verified State

- Local Mac agent rebuild/relaunch works.
- iOS Simulator build/install/launch works.
- The app auto-connects to the saved local environment.
- App-owned logs live in the Simulator container at `Documents/app-debug.log`.
- Deep-link control covers chats, windows, tabs, files, git, environments, and stop-run.
- Performance metrics already land in `app-debug.log` for auth, first token, completion, refresh, files, git, and debug FPS samples.
- Simulator screenshots work locally through `xcrun simctl io ... screenshot`.
- High-value controls and sheets now expose stable accessibility identifiers.

## Standard Loop

### 1. Build and launch

```bash
.claude/skills/agentic-testing/start-local-simulator.sh
```

This rebuilds and relaunches the Mac agent, builds the iOS app for Simulator, installs it, writes the saved local environment, and launches the app.

Important:

- After `simctl install`, wait briefly before `simctl launch` or `simctl openurl`.
- Use a short pause such as `sleep 1`.
- Otherwise Simulator can still be settling and you may capture the home screen instead of the app.

### 2. Stream logs

```bash
.claude/skills/agentic-testing/stream-simulator-logs.sh
```

This is the main debugging surface.

### 3. Navigate by deep link

```bash
.claude/skills/agentic-testing/open-repo-conversation.sh
.claude/skills/agentic-testing/open-simulator-url.sh settings
.claude/skills/agentic-testing/open-simulator-url.sh memories
.claude/skills/agentic-testing/open-simulator-url.sh plans
.claude/skills/agentic-testing/open-simulator-url.sh whiteboard
.claude/skills/agentic-testing/open-simulator-url.sh usage
.claude/skills/agentic-testing/open-simulator-url.sh search
.claude/skills/agentic-testing/open-simulator-url.sh new-chat
.claude/skills/agentic-testing/open-simulator-url.sh refresh-chat
.claude/skills/agentic-testing/open-simulator-url.sh stop-run
```

For dynamic routes, pass the raw URL with `xcrun simctl openurl booted ...`.

Use `open-repo-conversation.sh` before core tests so the active conversation is rooted at the current repo path instead of whatever state the app happened to restore.

### 4. Send a message

```bash
.claude/skills/agentic-testing/send-simulator-message.sh "hello from codex"
```

### 5. Capture a screenshot

```bash
.claude/skills/agentic-testing/capture-simulator-screenshot.sh
```

This writes a PNG under `/tmp/cloude-simulator-shots/` and prints the path.

## Verified Routes

- Chat: `cloude://send?text=...`, `cloude://conversation/new`, `cloude://conversation/duplicate`, `cloude://conversation/refresh`
- Conversation config: `cloude://conversation/model?value=...`, `cloude://conversation/effort?value=...`, `cloude://conversation/environment?id=...`
- Windows: `cloude://window?index=...`, `cloude://window/new?type=chat|files|gitChanges`, `cloude://window/edit`, `cloude://window/close`
- Tabs/surfaces: `cloude://tab?type=chat|files|gitChanges`, `cloude://settings`, `cloude://memory`, `cloude://memories`, `cloude://plans`, `cloude://whiteboard`, `cloude://usage`, `cloude://search`
- Files/git: `cloude://file/...`, `cloude://files?path=...`, `cloude://git?path=...`, `cloude://git/diff?path=...&file=...&staged=true|false`
- Runtime: `cloude://run/stop`, `cloude://screenshot`
- Environment: `cloude://environment/select?id=...`, `cloude://environment/connect?id=...`, `cloude://environment/disconnect?id=...`

## Perf Signals

- `environment.auth`
- `chat.firstToken`
- `chat.complete`
- `conversation.refresh`
- `usage.open`
- `memories.open`
- `plans.open`
- `files.directory`
- `file.load`
- `file.fullQuality`
- `git.status`
- `git.diff`
- `debug sample fps=<n> owcPerSec=<n>`

## Accessibility IDs

- Main shell: `main_chat_view`, `toolbar_settings_button`, `toolbar_close_window_button`, `toolbar_title`
- Window control: `window_picker`, `window_picker_<index>`, `window_add_button`, `window_tab_bar`, `window_tab_chat`, `window_tab_files`, `window_tab_gitChanges`
- Chat input: `chat_input_row`, `chat_input_field`, `chat_primary_action`, `chat_add_photo_button`, `chat_add_file_button`, `chat_record_button`, `chat_effort_picker`, `chat_model_picker`
- Settings: `settings_view`, `settings_close_button`, `settings_theme_button`, `environment_card_<uuid>`, `environment_symbol_button_<uuid>`, `environment_power_button_<uuid>`, `environment_delete_button_<uuid>`, `environment_add_button`
- Sheets: `conversation_search_sheet`, `conversation_search_close_button`, `usage_sheet`, `usage_close_button`, `memories_view`, `memories_close_button`, `plans_view`, `plans_close_button`, `whiteboard_view`
- File/git: `file_preview_view`, `file_preview_close_button`, `file_preview_toggle_diff_button`, `file_preview_wrap_lines_button`, `file_preview_toggle_source_button`, `git_diff_view`, `git_diff_close_button`
- Whiteboard: `whiteboard_undo_button`, `whiteboard_redo_button`, `whiteboard_send_snapshot_button`, `whiteboard_export_button`, `whiteboard_close_button`, `whiteboard_tool_hand`, `whiteboard_tool_multi_select`, `whiteboard_tool_rect`, `whiteboard_tool_ellipse`, `whiteboard_tool_triangle`, `whiteboard_tool_text`, `whiteboard_tool_pencil`, `whiteboard_tool_arrow`

## Workflow

1. Launch the stack.
2. Start log streaming.
3. Open a fresh conversation rooted at the current working directory.
4. Trigger the flow under test with deep links or scripted send.
5. Read app logs first.
6. Take screenshots only when the UI itself matters.

## Core Verification

Run this after any meaningful app change. These are the default checks unless the change is narrowly scoped and clearly cannot affect them.

Before running the suite, switch the active conversation to `haiku` to reduce token cost unless the change specifically targets model behavior:

```bash
.claude/skills/agentic-testing/open-repo-conversation.sh
xcrun simctl openurl booted "cloude://conversation/model?value=haiku"
```

This maps to the same conversation model control exposed in the input action menu / long-press send flow, but the deep link is the deterministic path for smoke checks.

### 1. Connection bootstrap

Verify the app launches and authenticates automatically.

Pass criteria in `app-debug.log`:

- `connectEnvironment ...`
- `start name=environment.auth ...`
- `finish name=environment.auth ... success=true`

### 2. Long markdown streaming

This is the highest-priority check. If streaming is broken, the app is effectively unusable.

Send a prompt that forces a multi-paragraph markdown response, for example:

```bash
.claude/skills/agentic-testing/send-simulator-message.sh "Write a long markdown answer with 8 sections, headings, bullet lists, and a short table about the architecture of this repo."
```

Pass criteria:

- `status ... state=running`
- multiple `assistant output ...` events, not just one short burst
- `finish name=chat.firstToken ...`
- `finish name=chat.complete ...`
- final live-message finalize log

What to watch for:

- no assistant output after `state=running`
- only a final message with no intermediate streaming
- missing `chat.firstToken`
- repeated FPS collapse during streaming

### 3. Tool-call streaming

Send a prompt that should trigger one or more tool calls, for example:

```bash
.claude/skills/agentic-testing/send-simulator-message.sh "Read the README and summarize the project structure in markdown."
```

Pass criteria:

- `tool call ...`
- `tool result ...`
- interleaved assistant output before or after tool activity
- `finish name=chat.complete ...`

This protects the most important “agent actually works” path, not just plain text rendering.

### 4. Abort / stop-run behavior

Send a request that should take a bit longer, then stop it quickly:

```bash
.claude/skills/agentic-testing/send-simulator-message.sh "Read the entire repo and write a detailed architecture summary with many citations."
.claude/skills/agentic-testing/open-simulator-url.sh stop-run
```

Pass criteria:

- `stop run convId=...`
- run returns to `state=idle`
- incomplete timing state is cleaned up, for example `cancel name=chat.firstToken ... reason=idle`

### 5. One file flow and one git flow

These are secondary, but still worth checking after larger UI or networking changes.

Suggested checks:

```bash
xcrun simctl openurl booted "cloude://file/Users/soli/Desktop/CODING/cloude/README.md"
xcrun simctl openurl booted "cloude://git?path=/Users/soli/Desktop/CODING/cloude"
xcrun simctl openurl booted "cloude://git/diff?path=/Users/soli/Desktop/CODING/cloude&file=Cloude/Cloude/App/CloudeApp+Actions.swift&staged=false"
```

Pass criteria:

- `finish name=file.load ...`
- `finish name=git.status ...`
- `finish name=git.diff ...`

### 6. Perf sanity

Do not treat “functionally correct” as enough.

During the checks above, inspect:

- `chat.firstToken`
- `chat.complete`
- `environment.auth`
- `debug sample fps=<n> owcPerSec=<n>`

Escalate if:

- first-token latency is obviously much worse than normal for the same local setup
- completion latency regresses sharply without a good reason
- FPS repeatedly collapses during ordinary chat streaming or sheet presentation

### Skip by exception, not by default

Do not replace these checks with lower-value flows like adding a new environment unless the change specifically targets that area. The core suite should stay centered on:

- connection
- streaming text
- streaming with tool calls
- abort behavior
- basic file/git surfaces
- perf sanity

## Notes

- If `simctl openurl` hits sandbox restrictions, rerun outside the sandbox.
- Prefer the app-owned log file over system logs for performance and app behavior.
- If `simctl get_app_container` resolves to a stale path right after reinstall, rerun it once.
- If the user wants to ship a build, use `deploy` instead.
