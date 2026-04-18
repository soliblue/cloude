# Interactive Terminal (PTY + stdin support) {terminal}
<!-- priority: 10 -->
<!-- tags: relay, agent -->

> Added PTY-based interactive terminal with stdin support and per-window isolation.

## Problem
The terminal tab runs commands via `spawn('bash', ['-c', cmd])` with no stdin pipe. Interactive CLIs like `codex --login`, `npm init`, `ssh` fail because they can't read user input. Also, all terminal windows shared one PTY session and always routed to the same environment.

## Solution
Replace `spawn` with a PTY (pseudo-terminal) so the spawned process thinks it's running in a real terminal. Stream output in real-time and accept stdin from the iOS app via WebSocket. Each window gets its own isolated PTY keyed by `terminalId`, and routes to the correct environment via `environmentId`.

## Changes

### Linux Relay (DONE)
- [x] Add `node-pty` dependency to `linux-relay/package.json`
- [x] Rewrite `handleTerminalExec` in `handlers-terminal.js` to use PTY
- [x] Stream output chunks in real-time instead of buffering until exit
- [x] Add `handleTerminalInput` function to pipe stdin to running PTY process
- [x] Add `terminal_input` case in `handlers.js` message router
- [x] Track active terminal per `terminalId` (not per ws connection)
- [x] 10-minute idle timeout kills abandoned PTY sessions
- [x] Cleanup all terminals for a ws on disconnect
- [x] New `terminal_exec` kills existing PTY for that terminalId before spawning
- [x] Echo `terminalId` back in `terminal_output` messages

### iOS App (DONE)
- [x] Add `ClientMessage.terminalInput(text: String, terminalId: String?)` to `ClientMessage.swift`
- [x] Add `terminalId` to `ClientMessage.terminalExec`
- [x] Add `terminalId` to `ServerMessage.terminalOutput` and `ConnectionEvent.terminalOutput`
- [x] Add `terminalInput(text:terminalId:environmentId:)` method to `ConnectionManager+API.swift`
- [x] Update `TerminalView.swift`:
  - Accepts `environmentId` and `terminalId` (window UUID) props
  - Input bar stays active during execution (not disabled)
  - Prompt changes from `$` to `>` (green) when executing
  - Submit sends `terminalInput` with newline instead of `terminalExec`
  - Allows sending empty enter (just newline) while executing
  - Filters incoming `terminal_output` events by `terminalId`
- [x] `MainChatView+Windows.swift` passes `conversation.environmentId` and `window.id.uuidString`
- [x] `EnvironmentConnection+MessageHandler` passes `terminalId` through

### Mac Agent (DONE)
- [x] PTY support via `openpty()` in `Cloude_AgentApp+Handlers.swift`
- [x] Handle `terminal_input` message type in `AppDelegate+MessageHandling.swift`
- [x] Stream output in real-time from PTY master fd
- [x] Write stdin to PTY master fd on `terminal_input`
- [x] Active terminals keyed by `terminalId` string (fallback to connection ID)
- [x] Each entry stores `terminalId` and `connection` for routing output back
- [x] 10-minute idle timeout kills abandoned PTY sessions
- [x] Cleanup all terminals for a connection on disconnect via `onDisconnect` callback
- [x] `WebSocketServer.onDisconnect` callback, fired from `removeConnection`
- [x] New `terminal_exec` kills existing PTY for that key before spawning
- [x] Guard against double-close of file descriptors
- [x] Echo `terminalId` back in all `terminal_output` messages

## Protocol
- `terminal_exec` - start a new PTY process (kills existing for that terminalId)
  - Fields: `command`, `workingDirectory`, `terminalId` (optional)
- `terminal_input` - send text to stdin of running PTY
  - Fields: `text`, `terminalId` (optional)
- `terminal_output` - output from PTY
  - Fields: `output`, `exitCode` (null = streaming, number = exited), `isError`, `terminalId` (optional)

## Next: SwiftTerm for proper TUI support

The current ANSI parser in `TerminalView.swift` renders text linearly - it strips cursor movement / screen positioning escapes. TUI apps (codex, htop, vim) write to specific screen positions, so they render as garbage.

**Solution**: Replace `FlowTextView` with [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) - a proper terminal emulator Swift package. It handles all xterm escape sequences, cursor positioning, scrollback, colors, etc.

### What was done
- [x] Add SwiftTerm Swift Package dependency to the Xcode project (v1.11.2)
- [x] Replace `FlowTextView` + `parseANSI` with `SwiftTermWrapper` (UIViewRepresentable wrapping SwiftTerm.TerminalView)
- [x] Pipe raw PTY output directly to SwiftTerm via `TerminalBridge.feed()` - no ANSI parsing needed
- [x] Remove custom `parseANSI`, `ANSISegment`, `FlowTextView`, `buildLines`, `CommandBlock` code
- [x] Keep: command history strip, quick commands, input bar UX ($ vs > prompt), empty state
- [x] Style SwiftTerm to match ocean theme (background color, white foreground, monospaced 13pt)
- [x] Command prompt rendered as colored ANSI text (`$ cmd` in cyan) fed to SwiftTerm
- [x] Exit code rendered as colored ANSI (`[exit 0]` green, `[exit 1]` red)
- [x] Clear button sends VT100 clear screen sequence to SwiftTerm
- [x] Mac agent TERM restored to `xterm-256color` (SwiftTerm handles all escape sequences)

### Why SwiftTerm
- Battle-tested xterm emulator, handles everything (cursor, scrollback, mouse, 256-color, true color)
- Removes ~100 lines of custom ANSI parsing that will never be complete
- TUI apps (codex, htop, vim, ssh) just work
- Has iOS support (`SwiftTerm.TerminalView` for UIKit, wrappable in SwiftUI)

## Safety
- PTY killed on: disconnect, new command (same terminalId), 10min idle timeout
- Server crash: kernel sends SIGHUP to PTY child when master fd closes
- One PTY per terminalId (new command kills old for same ID)
- Multiple windows can run independent PTY sessions simultaneously
