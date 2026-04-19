# Architecture Explorations

Working doc. Not a spec. The goal: land on a framework where file placement and naming are predictable without judgment calls.

## The pain

- `EnvironmentConnection` is ~700 lines doing git, files, tools, lifecycle, decoding, state — a god object
- `+extension` splits feel random (`+Handlers` vs `+MessageHandler` vs `+CommandHandlers` — what's the difference?)
- "Shared" has become a default bucket instead of an earned one
- Same week, same codebase: `EnvironmentConnection` collapses extensions into one file while `WindowSwitcher` splits into five. No rule is at work.
- Files contain multiple types; filenames don't reflect what's inside.

## Core instinct: thin transport + feature-owned handlers

`EnvironmentConnection` should do one job: move messages. Features own the meaning.

- **Transport** (Shared): WebSocket lifecycle, reconnect, encode, decode, publish inbound typed events, accept outbound messages
- **Features**: each one subscribes to the messages it cares about and owns the logic

That means git status/diff logic moves out of `Shared/Services/GitStatusService` into `Features/Git/Services/`. File browsing logic moves into `Features/Files/`. Tool results go to `Features/Conversation/`. The transport doesn't know what any message means.

### The mental model: feature-owned API clients

Think REST client. `URLSession` is shared infrastructure. Each feature has its own API service built on top: `GitAPI.status(path:)`, `FilesAPI.browse(path:)`. Messages are request/response DTOs (they stay in `CloudeShared`). Inbound server pushes are typed events each feature subscribes to.

### Why it feels right

- **Predictability**: "where does git status live?" → `Features/Git/`. Always. Not "Shared because it touches the connection."
- **Ownership**: each feature owns its state, its messages, its UI. The transport isn't a god.
- **Size**: `EnvironmentConnection` shrinks from 700 lines to ~150.
- **Scale**: new features don't bloat Shared — they bring their own API.

## What this pattern is called

No single canonical name. It's a composition of three well-known patterns:

1. **Gateway** (Fowler) — the transport is a gateway to the remote server. One place that knows the wire protocol.
2. **Service layer per bounded context** (DDD) — each feature is a bounded context with its own service that owns domain logic and state.
3. **Event bus / pub-sub** (Observer) — the gateway publishes typed events; services subscribe to their slice.

The closest single label is **Hexagonal / Ports and Adapters** (Cockburn): the transport is an adapter to an external system; each feature owns a port. The WebSocket could be swapped for HTTP, gRPC, or a mock without touching feature code.

### What it's not

- **Not TCA / Redux / Flux** — those are centralized (one store, one reducer, all state in one place). This is decentralized — each feature owns its own state. Opposite philosophy.
- **Not MVVM** — MVVM is a UI-layer pattern. This is a service-layer pattern. They compose (each feature view has a VM that talks to the feature's API).
- **Not a Mediator** — features don't talk to each other through the transport. They talk to the *server* through it. Cross-feature communication goes via imports or published state, rarely.

In iOS shorthand, this is often called "**feature-sliced architecture**" or "**API client per feature**." Firebase, Supabase, and Convex clients are all shaped this way under the hood.

## Shared vs Features, restated

Shared is **not** "stuff used by multiple features." Shared is **stuff owned by no feature.**

What belongs in Shared:
- **Infrastructure**: transport (`EnvironmentConnection`), notifications, deep links
- **Design system**: `Theme`, `AppColor`, `DS.*`
- **Cross-cutting types**: `ClientMessage`, `ServerMessage`, `ConnectionEvent`, primitive models
- **Reusable UI primitives** with no feature owner (e.g. `StreamingMarkdownView`, generic pills, loaders)

What doesn't:
- Domain logic (git, files, conversation) — those have feature owners
- UI components reused by two features — rare; usually a missing design-system primitive, or one feature imports the other

CLAUDE.md already allows cross-feature imports when the dependency is real, so "shared UI component" is almost always the wrong answer except for true primitives.

## When is something a feature?

Shared is stuff with no owner. Features are the owners. But the line between "this is a feature" and "this is just a sub-concern of a bigger feature" is a judgment call. Here's the test.

**A candidate is its own feature when it has state separate from its parent.**

If the only thing distinguishing it is a visual language (a different look for rendering the parent's data), it's a sub-view, not a feature. If it has its own data, its own lifecycle, its own async work → feature.

Applied to current concerns:

| Candidate | Separate state? | Verdict |
|---|---|---|
| Transcription | yes (in-flight, `whisperReady`) | own feature |
| ToolCall rendering | no — data lives in ConversationAPI | stays in Conversation |
| Markdown streaming | no — pure rendering | Shared primitive (`Shared/Views/`) |
| Message bubble | no — renders `ChatMessage` | stays in Conversation |
| Input bar | yes (draft text, attachments, slash commands) | its own thing under Workspace |
| Connection status | yes (phase, last error, reconnect attempts) | candidate for own feature |

Implications for the current mess:
- **Transcription** becomes `Features/Transcription/` with its own API, `MicButton`, and recording indicator. Workspace's input bar imports it.
- **`StreamingMarkdownView`** moves to `Shared/Views/` — it's a rendering primitive, not conversation-specific.
- **Conversation** stays big and that's correct. It's the product's main surface. Heavy ≠ mis-factored.

"Feature folder feels heavy" often just means "the feature is heavy." That's fine when the heaviness is one coherent concern done thoroughly. It's a problem only when unrelated concerns are stuck together — and the state-separation test is how you tell.

## The APIs we'd need

Mapping every message type to an owner. Transport + six feature APIs covers every current message.

**Transport** (`Shared/Services/EnvironmentConnection`)
- Send: `auth`, `ping`
- Receive: `authRequired`, `authResult`, `pong`, unmatched `error`
- Owns: WebSocket lifecycle, reconnect, request-ID correlation, encode/decode, typed event publisher, credential storage

**ConversationAPI** (`Features/Conversation/Services/ConversationAPI`)
- Send: `chat`, `abort`, `resumeFrom`, `syncHistory`, `suggestName`
- Receive: `output`, `status`, `sessionId`, `toolCall`, `toolResult`, `runStats`, `resumeFromResponse`, `historySync`, `historySyncError`, `messageUUID`, `nameSuggestion`
- Owns: live streaming state, session resumption logic, output draining

**FilesAPI** (`Features/Files/Services/FilesAPI`)
- Send: `listDirectory`, `getFile`, `getFileFullQuality`, `searchFiles`
- Receive: `directoryListing`, `fileContent`, `fileChunk`, `fileThumbnail`, `fileSearchResults`
- Owns: directory cache, file content cache, thumbnail cache, search results

**GitAPI** (`Features/Git/Services/GitAPI`)
- Send: `gitStatus`, `gitDiff`, `gitCommit`, `gitLog`
- Receive: `gitStatusResult`, `gitDiffResult`, `gitCommitResult`, `gitLogResult`
- Owns: in-flight dedup (current `GitStatusService`), per-repo error state

**EnvironmentAPI** (`Features/Environment/Services/EnvironmentAPI`)
- Receive-only: `defaultWorkingDirectory`, `skills`
- Owns: skill list cache, default working dir. Feeds Workspace's input bar for slash-command autocomplete.

**TranscriptionAPI** (`Features/Transcription/Services/TranscriptionAPI`)
- Send: `transcribe`
- Receive: `transcription`, `whisperReady`
- Lives in its own feature. Workspace's input bar imports `MicButton` from here.

### Tricky cases resolved
- `toolResult` — ConversationAPI owns it. Other features that care (Files showing a written file, Git reacting to a commit tool) observe Conversation's published state, not the raw event.
- `error` — Transport correlates to in-flight request via ID; unmatched errors publish as a global connection event.
- Receive-only APIs (`EnvironmentAPI`) are fine — not every API needs outbound messages.

## State ownership and scoping

Each API is a stateful service, not a stateless function caller. The current god-object state redistributes as follows:

### Scoping

| Scope | APIs |
|---|---|
| **Per-app** (or per environment if multi-env) | Transport |
| **Per-environment** | FilesAPI, GitAPI, EnvironmentAPI, TranscriptionAPI |
| **Per-conversation** | ConversationAPI |

File/git caches are scoped to a workspace root, not a conversation — two conversations in the same environment share them. Environment config (skills, default working dir) is obviously per-environment. Transcription is tied to the mic button, which is per-environment.

Conversation is the only per-conversation API because every piece of state it holds (live streaming, agent state, session ID, tool call assembly, history cursor) is per-conversation. Creating `ConversationAPI` per conversation makes state isolation automatic and lifecycle cleanup trivial (close conversation → API deinits → state gone). No more dict-of-outputs to manage.

### What each API holds

**Transport**
- Credentials (host, port, auth token, connection token)
- Connection phase (connecting / authenticating / authenticated / disconnected)
- Reconnect state (attempt count, backoff timer)
- In-flight request map (`[UUID: Continuation]`)
- Latency measurements (ping/pong)

**ConversationAPI** *(per conversation)*
- Live streaming state (text, tool calls in progress, phase)
- Agent state (idle / running / compacting)
- Session ID
- Run stats (tokens, cost)
- History sync cursor
- Name suggestion

**FilesAPI**
- Directory listing cache
- File content cache (`LoadedFileState`)
- Thumbnail cache
- Chunked transfer state (`ChunkProgress`)
- File search result cache
- Per-path error state

**GitAPI**
- In-flight dedup
- Git log cache per repo
- Git diff cache per `GitDiffCacheKey`
- Per-repo/per-file error state

**EnvironmentAPI**
- Skill list cache
- Default working directory

**TranscriptionAPI**
- In-flight transcription state
- `whisperReady` flag
- Last result buffer

**Settings** (unchanged)
- User-entered credentials (the desired config; Transport holds the active one)
- User preferences

### API shape

Each API exposes:
1. **Async methods** for outbound requests (`func status(path:) async throws -> GitStatus`)
2. **`@Published` properties** for state the UI observes (`@Published var statuses: [Path: GitStatus]`)
3. **Internal subscription** to its slice of transport events, updating published state

Views observe the API's published state directly. Where orchestration is genuinely multi-API (WorkspaceStore coordinating environment + conversation lifecycle), a thin orchestrating store stays — but it's wiring, not state ownership.

## Naming framework

### The one-component rule (non-negotiable)

**One file = one component. Filename = component name. Always.**

If a file declares `struct WindowSwitcherItem`, the file is `WindowSwitcherItem.swift`. Not `WindowSwitcher+Parts.swift`. Not a second type declared at the bottom. If you need two components, that's two files.

This is the single most load-bearing rule. Every other naming question gets easier when this is enforced. Given a file, you know what's in it. Given a type, you know what file to open. The file system becomes a symbol table.

Exceptions: none.
- A type small enough that "it feels silly to give it a file" should be inlined into its only caller as a computed property, not declared as a standalone type. If it's a type, it gets a file.
- Private nested types inside the owner are never the answer either — they hide from search and produce the same "what's in this file?" problem.

### `+Extension.swift` files

Only for slicing behavior on an existing type when the parent file exceeds the size threshold. Name the extension by **responsibility**, not by **shape**:

- Good: `ConversationStore+Messaging.swift`, `WorkspaceStore+Lifecycle.swift`, `EnvironmentConnection+Networking.swift`
- Bad: `ConversationView+Components.swift`, `WorkspaceStore+Helpers.swift`, `FooStore+Shared.swift`

If you can't name the slice by responsibility, don't split — the real problem is the type has too many responsibilities. Fix *that* instead.

### Feature-local sub-views

If the sub-view has its own name and is referenced by that name from elsewhere, it gets its own file, owner-prefixed: `WindowSwitcherItem.swift`, `WindowSwitcherLabel.swift`. Same folder as the parent. Never nested inside another type.

### Shared is earned

Not by reuse count, but by absence of feature owner. If a thing has a natural feature home, it lives there. Shared is for transport, design tokens, cross-cutting types, and true rendering primitives — that's it.

## Open questions (resolve before committing to this)

1. **Subscription shape**: Combine publishers on the transport? A typed event bus? Each feature store owning its own subscription?
2. **Outbound path**: Inject the transport into each feature API via init? Or access via an app-level environment object?
3. **Decoding location**: Transport decodes once and publishes typed events (preferred — mirrors `URLSession` + `Codable`)? Or each feature decodes its own slice from raw frames?
4. **Per-conversation routing**: since `ConversationAPI` is per-conversation, something has to route inbound messages by conversation ID. Does the transport itself demux (cleanest — it can read the conversationId off every conversation-scoped message and publish per-conversation streams), or does a `ConversationsManager` hold `[ConversationID: ConversationAPI]` and forward, or does each API filter? Lean: transport demuxes.
5. **Fate of current stores**: `WorkspaceStore`, `ConversationStore` currently orchestrate. Do they become feature-level wiring around the feature API, or dissolve entirely?
6. **Connection lifecycle UI**: reconnect / error / authenticated — which surface shows this? Probably a dedicated connection-status feature that observes transport events.
7. **Request-ID correlation**: a small piece of infrastructure (`waitingRequests: [UUID: Continuation]`) lives in the transport. Confirm the shape before feature APIs depend on it.

## The meta-rule

**Name by responsibility, not by shape.** `+Networking` predicts contents; `+Shared` doesn't. `GitAPI` predicts; `ConnectionManager` doesn't. If a name could apply to anything, it's the wrong name.
