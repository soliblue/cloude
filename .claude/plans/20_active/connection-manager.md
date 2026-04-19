# ConnectionManager — one-file view

## Why it exists

`EnvironmentConnection` is **one** WebSocket to **one** agent (your Mac, or a Linux relay, or another machine). A user can have several environments configured. The app needs a single object above them that:

- Holds all the connections (`[UUID: EnvironmentConnection]`).
- Routes API calls (like "send this chat message") to the right connection — by conversation, by environment id, or by fallback to any authenticated one.
- Holds **cross-connection** state that isn't tied to any single socket: `conversationOutputs` (streaming text per conversation), `conversationEnvironments` (which env does this conversation belong to).
- Broadcasts events to the whole app via a single `events` `PassthroughSubject` the UI subscribes to.
- Manages iOS app lifecycle bits that span all connections: background-task budget while streaming, foreground-transition reconnect.

If we deleted `ConnectionManager` we'd have to scatter all of that across views and feature stores. It's the single owner.

## Tree

```
ConnectionManager
│
├── state
│   ├── connections                [UUID: EnvironmentConnection]  all active sockets, keyed by env
│   ├── events                     PassthroughSubject<ConnectionEvent, Never>  app-wide event bus
│   ├── conversationOutputs        [UUID: ConversationOutput]     streaming text/tools per conversation
│   ├── conversationEnvironments   [UUID: UUID]                   which env owns which conversation
│   ├── backgroundTaskId           iOS background-task handle while streaming
│   │
│   ├── (computed) isAnyAuthenticated   true if at least one connection is authed
│   ├── (computed) isAnyRunning         true if any conversation's output is non-idle
│   ├── (computed) processes            flat list of agent processes across all connections
│   ├── (computed) skills               deduped skills across all connections
│   ├── (computed) chunkProgress        first non-nil chunk progress across connections
│   └── (computed) fileCache            AggregateFileCache — looks up a path in every connection's cache
│
├── lookups (find the right connection / output)
│   ├── output(for: conversationId)         get or lazily create the ConversationOutput
│   ├── connection(for: environmentId?)     direct lookup by env id
│   ├── connectionForConversation(id)       lookup via conversationEnvironments mapping
│   └── anyAuthenticatedConnection()        fallback: first authed connection
│
├── lifecycle (connections + conversations)
│   ├── connectEnvironment(envId, host, port, token, symbol)
│   │                                        create or reuse an EnvironmentConnection, start it
│   ├── disconnectEnvironment(envId, clearCredentials)
│   ├── reconnectAll()                      call reconnectIfNeeded() on every connection
│   ├── registerConversation(convId, envId) remember which env owns a conversation
│   └── runningOutputs(for: envId)          non-idle outputs belonging to a specific env
│
├── iOS app lifecycle
│   ├── handleForegroundTransition()        on foreground: snapshot any in-flight streams, reconnect
│   ├── beginBackgroundStreamingIfNeeded()  ask iOS for background time while streaming
│   └── endBackgroundStreaming()            release the background-task budget
│
└── outgoing API (in ConnectionManager+API.swift)
    ├── connectionForSend(environmentId?, conversationId?)
    │                                        pick which connection to send on
    ├── sendChat(...)                        send a chat message; kick off timers; mark running
    ├── abort(conversationId?)               cancel current turn
    ├── searchFiles / listDirectory / getFile / getFileFullQuality
    ├── gitStatus / gitLog / gitDiff
    ├── getProcesses / killProcess
    ├── syncHistory(sessionId, workingDirectory)
    ├── transcribe(audioBase64)              flip isTranscribing=true + send audio
    └── requestNameSuggestion(text, context, conversationId)
```

## Relationship to EnvironmentConnection

- EnvironmentConnection = transport. One socket, one agent.
- ConnectionManager = registry + router + conversation-level state + app lifecycle.

Views typically take a `ConnectionManager` (not a specific `EnvironmentConnection`) so they can call `connection.sendChat(...)` without knowing or caring which agent it goes to — the manager figures out the right socket from the conversation id.
