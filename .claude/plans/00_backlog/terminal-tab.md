# Terminal Tab + Inline Terminal Widget

Two surfaces for terminal access, sharing the same PTY backend:

1. **Terminal Tab** - general-purpose shell, always available alongside chat/files/git
2. **Inline Terminal Widget** - Claude spawns an interactive terminal embed in the chat when it needs user input or runs something interactive. Scoped, contextual, lives in the message flow.

## Architecture

The terminal tab follows the exact same pattern as file browser and git tabs:
- iOS sends a `ClientMessage` over WebSocket
- Agent executes and streams back `ServerMessage` responses
- iOS listens via `ConnectionEvent` and updates the UI

Key difference: terminal needs a **persistent shell session** (not one-off commands), so the agent spawns a long-lived bash process per connection and pipes stdin/stdout through the WebSocket.

## Implementation Plan

### Step 1: Shared Protocol (CloudeShared)

**ClientMessage.swift** - add:
- `case terminalInput(sessionId: String, input: String)` - send keystrokes/commands
- `case terminalResize(sessionId: String, cols: Int, rows: Int)` - resize signal
- `case terminalStart(workingDirectory: String)` - spawn a new shell session

**ServerMessage.swift** - add:
- `case terminalOutput(sessionId: String, data: String)` - stdout/stderr chunks
- `case terminalStarted(sessionId: String)` - shell is ready
- `case terminalEnded(sessionId: String, exitCode: Int)` - shell exited

**ConnectionEvent.swift** - add:
- `case terminalOutput(sessionId: String, data: String)`
- `case terminalStarted(sessionId: String)`
- `case terminalEnded(sessionId: String, exitCode: Int)`

### Step 2: Agent Side (Mac + Linux)

**New file: TerminalSession.swift / terminal-session.js**

- On `terminalStart`: spawn `/bin/bash` (or user's shell) with a pseudo-terminal (PTY)
- PTY is important - it gives us proper terminal behavior (colors, line editing, interactive programs)
- Pipe PTY output -> `ServerMessage.terminalOutput` over WebSocket
- On `terminalInput`: write to PTY stdin
- On `terminalResize`: send SIGWINCH to the PTY with new dimensions
- One shell session per connection, auto-cleanup on disconnect

**WebSocketServer** - add handlers:
- Route `terminalStart`, `terminalInput`, `terminalResize` to TerminalSession
- Forward terminal output back to the iOS client

**Mac agent (Swift)**: Use `Process` + `forkpty()` or `openpty()` for PTY
**Linux agent (Node.js)**: Use `node-pty` npm package (battle-tested, used by VS Code terminal)

### Step 3: iOS Tab System

**ChatWindow.swift** - add to WindowType enum:
- `case terminal` with icon `terminal.fill` or `apple.terminal`

**MainChatView+Windows.swift**:
- Add `case .terminal:` to the tab content switch
- Render `TerminalView(connection:, workingDirectory:)`

### Step 4: iOS Terminal View

**New file: TerminalView.swift** (~100 lines)

- Text input field at bottom (similar to GlobalInputBar but simpler)
- Scrollable output area above showing all terminal output
- On appear: send `terminalStart(workingDirectory:)` to agent
- On submit: send `terminalInput(sessionId:, input: command + "\n")`
- Listen to `connection.events` for `.terminalOutput` and append to display buffer
- Monospace font, dark background (terminal aesthetic)
- @State for command history, navigate with swipe gestures

**New file: TerminalView+Components.swift** (if needed)
- ANSI color parser (convert escape codes to SwiftUI attributed text)
- Command history UI

### Step 5: ConnectionManager Integration

**ConnectionManager+API.swift** - add:
- `func startTerminal(workingDirectory:, environmentId:)`
- `func sendTerminalInput(sessionId:, input:, environmentId:)`
- `func resizeTerminal(sessionId:, cols:, rows:, environmentId:)`

**EnvironmentConnection+MessageHandler.swift**:
- Handle `terminalOutput`, `terminalStarted`, `terminalEnded` server messages
- Forward as ConnectionEvents

## Key Files to Modify

| File | Change |
|------|--------|
| `CloudeShared/.../ClientMessage.swift` | Add terminal message types |
| `CloudeShared/.../ServerMessage.swift` | Add terminal response types |
| `Cloude/Services/ConnectionEvent.swift` | Add terminal events |
| `Cloude/Services/ConnectionManager+API.swift` | Add terminal API methods |
| `Cloude/Services/EnvironmentConnection+MessageHandler.swift` | Handle terminal messages |
| `Cloude/Models/ChatWindow.swift` | Add `.terminal` to WindowType |
| `Cloude/UI/MainChatView+Windows.swift` | Add terminal tab + content |
| **New:** `Cloude/UI/TerminalView.swift` | Terminal UI |
| **New:** `Cloude Agent/Services/TerminalSession.swift` | PTY session (Mac) |
| **New:** `agent-linux/terminal-session.js` | PTY session (Linux) |
| `Cloude Agent/Services/WebSocketServer.swift` | Route terminal messages |
| `agent-linux/server.js` (or equivalent) | Route terminal messages |

## Phase 2: Inline Terminal Widget (via MCP)

Extends the existing widget MCP pattern. Claude calls a `terminal` tool, iOS renders a live interactive terminal inline in chat - just like quiz/flashcard widgets but stateful.

**How it fits the existing widget system:**
- All current widgets: Claude calls MCP tool -> MCP echoes JSON -> iOS renders native SwiftUI widget inline
- Terminal widget: same flow, but the widget stays **live** after render - connected to a PTY session on the agent
- First "stateful" widget - all others are static/self-contained

**MCP server (`.claude/widgets-mcp/server.js`)** - add:
```js
{
  name: "terminal",
  description: "Spawn an interactive terminal in the chat. Use when you need the user to handle interactive input.",
  inputSchema: {
    type: "object",
    properties: {
      command: { type: "string", description: "Command to run (e.g. 'npm init')" },
      workingDirectory: { type: "string", description: "Working directory" },
      reason: { type: "string", description: "Why the terminal is needed" },
    },
    required: ["command"],
  },
}
```

**UX flow:**
1. Claude calls `terminal(command: "npm init", reason: "needs interactive setup")`
2. MCP returns JSON, iOS detects `terminal` tool name
3. iOS renders `InlineTerminalWidget` in chat (dark bg, monospace, ~6-8 lines)
4. Agent spawns PTY, runs the command, streams output to the widget via `terminalOutput` messages
5. User sees the prompt, types answers directly in the widget
6. When process exits, widget shows "ended" state and collapses
7. Claude reads final output and continues

**Key difference from other widgets:**
- Widget needs a `sessionId` linking it to a PTY on the agent
- iOS sends `terminalInput(sessionId, input)` when user types in the widget
- Agent streams `terminalOutput(sessionId, data)` back, widget updates live
- Widget reuses the same `TerminalView` component from the tab, just compact

**Files:**
- `.claude/widgets-mcp/server.js` - add `terminal` tool definition
- **New:** `Cloude/UI/Widgets/WidgetView+Terminal.swift` - inline terminal widget (follows widget naming pattern)
- `Cloude/UI/Widgets/WidgetView+Registry.swift` - register terminal widget type
- Agent: link terminal tool calls to PTY sessions

## Phase 3: Claude as Terminal User

The big idea: Claude can use the terminal as a tool. When Claude needs interactive input or wants to run long-lived processes, it sends commands to the PTY and reads output back.

**How it works:**
- New tool available to Claude Code: `Terminal` (or extend Bash tool)
- Claude sends `terminalInput` to write to the PTY
- Agent streams `terminalOutput` back to Claude's context
- Claude can read output, decide what to type next, handle prompts
- iOS app shows all of this happening in the terminal tab in real-time

**Use cases this unlocks:**
- `y/n` confirmation prompts (pre-commit hooks, install scripts)
- Interactive CLIs (`npm init`, `docker login`, `ssh-keygen`)
- Long-running processes (`docker compose up`, `npm run dev`) - start in terminal, monitor from chat
- Anything that currently forces the user to SSH in manually

**Implementation:**
- Agent exposes the terminal PTY as a Claude Code tool via MCP or custom tool
- Tool input: command/text to send to PTY
- Tool output: last N lines of PTY output since last read
- Auto-switch user to terminal tab when Claude is using it (so they can watch)
- User can also type in the terminal while Claude is using it (shared session)

## Nice to Have (Later)
- [ ] Tab completion suggestions from the agent
- [ ] Quick command buttons (ls, git status, top, etc.)
- [ ] Multiple terminal sessions per environment
- [ ] Copy/paste support for terminal output
- [ ] Split view: terminal + chat side by side on iPad
- [ ] Detect URLs in terminal output and make tappable
