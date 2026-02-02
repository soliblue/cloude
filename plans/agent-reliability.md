# Agent Reliability Plan

## Goals
- Make the macOS agent more robust under long-running sessions and multiple connections.
- Reduce silent failures and improve observability.
- Harden file and git operations without changing the core workflow.

## Current Observations
- Stream parsing in `ClaudeCodeRunner` is tolerant but can duplicate content.
- `extractCloudeCommands` exists but is unused; cloude commands rely on Bash tool calls.
- File reads are fully buffered; large files can be memory heavy.
- Git status relies on `origin/HEAD`, which fails for repos without a remote.
- Logging is a mix of `print` and `Log`.

## Opportunities

### Runner and Streaming
- Use a single canonical stream path to reduce duplicate output.
- Improve JSON line parsing error handling and emit structured errors.
- Attach exit status and stderr summaries to the final response.

### File Service
- Add path normalization and simple denylist (e.g., .git, node_modules) for browsing.
- Stream file chunks directly from disk instead of loading entire file into memory.
- Cache thumbnails to avoid regenerating on repeated opens.

### Git Service
- Use `git status -sb` and parse ahead/behind from status when no remote.
- Add staged vs unstaged diffs and rename handling.
- Add lightweight "stage/unstage" commands for mobile UI.

### Observability
- Replace `print` with `Log` consistently.
- Add a small rolling log buffer surfaced in the macOS status view.

## Proposed Phases

### Phase 0 - Stability
1. Clean up stream parsing and prevent duplicate output accumulation.
2. Surface stderr and exit codes in the final agent message.
3. Consistent logging via `Log`.

### Phase 1 - File/Git Reliability
1. Stream file reads and add caching for thumbnails.
2. Expand Git support (no-remote repos, staged diff).
3. Add file access guardrails (denylist, size thresholds).

### Phase 2 - Observability
1. Add agent diagnostics view (recent logs, active processes, disk usage).
2. Add per-run trace info for debugging dropped connections.

## Notes / Dependencies
- Runner: `Cloude/Cloude Agent/Services/ClaudeCodeRunner.swift` and `ClaudeCodeRunner+Streaming.swift`.
- File service: `Cloude/Cloude Agent/Services/FileManager.swift`.
- Git service: `Cloude/Cloude Agent/Services/GitService.swift`.
- Status UI: `Cloude/Cloude Agent/UI/StatusView.swift`.
