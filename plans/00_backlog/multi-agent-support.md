# Multi-Agent Support

## Summary
Support connecting to multiple Mac agents from the iOS app. Tap the logo to switch between them (start with 2, expandable later).

## Use Case
- Home Mac + Work Mac, each running their own Cloude Agent
- Tap logo to toggle active agent, conversation list swaps entirely
- Also enables distributing the app — each user runs their own agent

## Architecture Changes

### ConnectionManager
- Array of server configs (host, port, token, name) instead of one
- Track active server ID
- On switch: disconnect current, connect to new
- Reconnection logic stays the same, just per-server

### ConversationStore
- Conversations scoped by server ID
- Switching agents swaps the conversation list
- Each server maintains independent state

### Settings UI
- "Servers" section to add/edit/remove agents
- Each server: name, host, port, token
- Token stored in Keychain per server

### Logo Tap
- If 2 servers: toggle between them
- If 3+: show a picker/menu
- Visual indicator of active agent (color tint or icon variant)

### Persistence
- Server configs in Keychain (tokens) + UserDefaults (host/port/name)
- Conversations already persist per-session via the agent

## What Stays the Same
- WebSocket protocol — unchanged
- Message format — unchanged
- Mac agent / Claude Code runner — untouched
- Chat UI, tool rendering, markdown, everything else — unchanged

## Estimate
Medium effort — mostly ConnectionManager, ConversationStore, Settings, logo gesture.

## Codex Review

**Findings (ordered by severity)**

1. **High: Security/trust model is underspecified**
- Storing tokens in Keychain is good, but the plan doesn’t cover TLS requirements, certificate validation/pinning, or protection against connecting to wrong hosts.
- Improvement: require `wss`, validate cert chain strictly, optionally pin server cert/public key per server, and add “last verified fingerprint” in server settings.

2. **High: Switch-state race conditions are likely**
- “Disconnect current, connect new” can cause stale events/messages from old socket to mutate active UI/state if callbacks are not server-scoped.
- Improvement: tag every connection event and message with `serverID`, ignore mismatched events, and isolate per-server connection state machines.

3. **High: Data model migration is missing**
- Moving from single-server to multi-server needs migration for existing users (default server creation, mapping legacy conversation cache/state).
- Improvement: define explicit migration steps and rollback behavior for failed migration.

4. **Medium: “Everything else unchanged” is optimistic**
- Server-scoped behavior affects more than `ConnectionManager` and `ConversationStore`: drafts, unread counts, in-flight tool executions, reconnect backoff, and error banners.
- Improvement: audit all global/singleton state and mark each as `global` vs `perServer`.

5. **Medium: Deletion/rotation lifecycle is incomplete**
- Removing a server while connected or with active tasks can orphan state.
- Improvement: add rules for safe removal, token rotation flow, and “server unavailable” recovery UX.

6. **Medium: UX ambiguity for logo-tap switch**
- Logo tap for a destructive context switch can be accidental and non-obvious.
- Improvement: keep logo shortcut, but add explicit current-server chip/title and a dedicated switcher in top bar/settings.

7. **Medium: No testing matrix in plan**
- Multi-agent adds combinatorial state paths.
- Improvement: add tests for rapid switching, reconnect during switch, per-server state isolation, and app relaunch restoration to last active server.

8. **Low: Scalability constraints are not defined**
- “Start with 2, expandable later” needs clear bounds and policy.
- Improvement: define max server count now (e.g., 10), ordering, naming collisions, and validation rules.

**Suggested plan refinements**

1. Add a `ServerRegistry` abstraction (CRUD + validation + migration).
2. Make `ConnectionManager` explicitly per-server with a thin `ActiveServerController` on top.
3. Namespace all persisted state keys by `serverID`.
4. Add a safe-switch flow:
- preserve unsent draft per server
- cancel or detach in-flight tasks predictably
- switch only after old socket is fully quiesced (or hard-isolated by ID gating)
5. Define an MVP acceptance checklist:
- switch latency target
- zero cross-server message leakage
- restart restores last active server
- remove/edit server without app restart
6. Add observability:
- structured logs with `serverID`
- counters for connect failures, switch failures, and stale-event drops

This is a solid direction; the biggest gap is operational correctness under switching/reconnect and a tighter security/migration spec.
