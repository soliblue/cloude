# Android App MVP {android}
<!-- priority: 1 -->
<!-- tags: android, kotlin, mvp -->

> Create Android Kotlin app with core chat functionality, WebSocket connection to Mac agent/Linux relay.

## Background

Cloude is an iOS app that controls Claude Code remotely over WebSocket. The Mac agent or Linux relay spawns CLI processes and streams output back. The iOS app has ~120 Swift files covering chat, file browser, git, whiteboard, plans, memories, settings, and more.

The Android version needs to speak the same WebSocket protocol (ServerMessage/ClientMessage) to connect to the same backend agents. No agent changes needed.

## Goals

- Standalone Android app in `android/` at project root
- Connects to existing Mac agent / Linux relay over WebSocket (same protocol)
- Core chat: send messages, receive streaming output, display tool calls
- Basic settings: environment config (host, port, token)
- Same accent color (orange rgb 0.8/0.447/0.341)
- Modern Android stack: Kotlin, Jetpack Compose, Material 3

## Architecture

```
android/
├── app/
│   └── src/main/
│       ├── java/com/cloude/app/
│       │   ├── CloudeApp.kt              # Application class
│       │   ├── MainActivity.kt
│       │   ├── data/
│       │   │   ├── model/                 # Data classes matching SharedTypes
│       │   │   │   ├── ServerMessage.kt   # Sealed class (40+ cases)
│       │   │   │   ├── ClientMessage.kt   # Sealed class (38 cases)
│       │   │   │   ├── Conversation.kt
│       │   │   │   ├── ChatMessage.kt
│       │   │   │   ├── ToolCall.kt
│       │   │   │   └── Environment.kt
│       │   │   └── repository/
│       │   │       ├── ConversationRepository.kt
│       │   │       └── EnvironmentRepository.kt
│       │   ├── network/
│       │   │   ├── WebSocketClient.kt     # OkHttp WebSocket
│       │   │   ├── MessageSerializer.kt   # JSON encode/decode
│       │   │   └── ConnectionManager.kt   # Multi-env orchestration
│       │   └── ui/
│       │       ├── theme/
│       │       │   ├── Theme.kt           # Material 3 + custom tokens
│       │       │   ├── Color.kt
│       │       │   └── Type.kt
│       │       ├── chat/
│       │       │   ├── ChatScreen.kt
│       │       │   ├── MessageBubble.kt
│       │       │   ├── InputBar.kt
│       │       │   └── ToolCallLabel.kt
│       │       ├── settings/
│       │       │   └── SettingsScreen.kt
│       │       └── navigation/
│       │           └── NavGraph.kt
│       └── res/
├── build.gradle.kts
└── gradle/
```

## Implementation Phases

### Phase 1: Project Scaffolding
- Create Gradle project with Kotlin DSL
- Configure dependencies: Compose, OkHttp, kotlinx.serialization, Hilt
- Set up theme with orange accent, dark default
- Basic navigation (chat, settings)

### Phase 2: WebSocket Protocol
- Port ServerMessage sealed class (start with core cases: output, status, toolCall, toolResult, error, authRequired, authResult, sessionId)
- Port ClientMessage sealed class (start with: chat, abort, auth)
- WebSocket client using OkHttp
- JSON serialization matching iOS protocol exactly
- Connection state management (connecting, connected, authenticated, disconnected)

### Phase 3: Core Chat
- ChatScreen with message list (LazyColumn)
- MessageBubble composable (user vs assistant styling)
- Streaming text display (append as chunks arrive)
- Tool call display (inline pills, expandable)
- InputBar with text field and send button
- Conversation persistence (Room or file-based JSON to match iOS)

### Phase 4: Settings & Multi-Environment
- Environment config screen (add/edit/delete)
- Host, port, token fields
- Connection status indicator
- Environment persistence (DataStore or file-based JSON)

### Phase 5: Polish
- Status bar connection indicator
- Error handling and reconnection
- Basic markdown rendering (code blocks, bold, italic, links)
- Copy message text
- Dark/light theme support

## Tech Stack

| Concern | Library |
|---------|---------|
| UI | Jetpack Compose + Material 3 |
| Navigation | Compose Navigation |
| WebSocket | OkHttp |
| Serialization | kotlinx.serialization |
| DI | Hilt |
| Persistence | File-based JSON (matching iOS approach) |
| Async | Kotlin Coroutines + Flow |
| Markdown | Custom or compose-markdown lib |

## Key Protocol Details (from iOS SharedTypes)

ServerMessage cases needed for MVP:
- `output(text)` - streaming assistant text
- `status(AgentState)` - idle/running/compacting
- `toolCall(name, input, toolId, parentToolId, textPosition)`
- `toolResult(toolId, resultSummary, resultOutput)`
- `error(message)`
- `authRequired` / `authResult(success)`
- `sessionId(id)`
- `runStats(durationMs, costUsd, model, inputTokens, outputTokens)`
- `messageUUID(uuid)`

ClientMessage cases needed for MVP:
- `chat(message, workingDir, sessionId, images, files, effort, model)`
- `abort`
- `auth(token)`

## Risks

- JSON protocol must match exactly or messages will be silently dropped
- Streaming markdown rendering is complex (iOS has ~15 files for this)
- OkHttp WebSocket reconnection needs careful handling
- Android background restrictions may kill WebSocket during long operations

## Open Questions

- Min Android API level? (suggest 26 / Android 8.0)
- Package name? (suggest `com.cloude.app`)
- Use Gradle version catalog?
