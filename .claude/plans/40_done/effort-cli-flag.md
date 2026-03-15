# Pass effort as --effort CLI flag

Effort level was prepended to the prompt as `/effort <level>`, which Claude Code interpreted as a slash command ("effort is not a skill"). Fixed to pass as `--effort <level>` CLI flag, matching how `--model` is already handled.

## Changes
- **Mac agent**: `ClaudeCodeRunner.swift` - removed `/effort` prompt prefix, added `--effort` to command args
- **Linux relay**: `runner.js` - same fix

**Files:** `Cloude Agent/Services/ClaudeCodeRunner.swift`, `linux-relay/runner.js`
