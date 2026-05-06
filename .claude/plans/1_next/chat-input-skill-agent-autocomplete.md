# Skill (/) and Agent (@) Autocomplete in ChatInputBar

## Context

`ChatInputBar` is a plain `TextField` today. Users typing a prompt have no way to reference project skills or subagents. The old app (cloude-main) triggered a pill picker on `/` (skills) and `@` (files). The v2 version keeps the same trigger ergonomics but repurposes `@` for **agents** (subagent names) rather than file paths, since v2 already has a dedicated Files tab.

The data model is already in place:
- `Skill` and `Agent` (Sessions/Logic) are plain `{ name, description }` Codables.
- `Session` has `@Transient var skills: [Skill]?` and `@Transient var agents: [Agent]?`.
- CLAUDE.md documents planned routes `GET /sessions/:id/skills` and `GET /sessions/:id/agents`.

Nothing UI-side, network-side, or daemon-side for these has been built yet. This plan covers all three layers.

**Serialization choice (cloude-main parity):** selection injects plain text. Selecting a skill splices `/<name> ` into the draft; selecting an agent splices `@<name> `. The daemon does not receive structured skill/agent metadata — claude itself resolves the `/` and `@` tokens in the prompt. This matches cloude-main and requires zero changes to `ChatService.send` or the daemon's chat path.

## Files to create

### `daemons/macos/src/Handlers/SkillsHandler.swift`
New handler. Route: `GET /sessions/:id/skills?path=…`.

Scans two locations and merges (project overrides user on name collision):
1. `~/.claude/skills/` — user-global skills.
2. `<path>/.claude/skills/` — project-scoped skills (where `path` is the session cwd, query param).

For each directory, enumerate entries:
- `*.md` file → skill name is the basename without extension.
- Subdirectory containing `SKILL.md` → skill name is the directory name; read `SKILL.md` for frontmatter.

Parse YAML frontmatter (`---\n...\n---`) from the markdown to extract `description`. No frontmatter → description is empty string. Return `[{name, description}]` as JSON.

Match existing handler style (`FilesHandler.list` is the closest reference — takes a path query param, returns JSON, no streaming).

### `daemons/macos/src/Handlers/AgentsHandler.swift`
New handler. Route: `GET /sessions/:id/agents?path=…`.

Same shape and scan pattern, against:
1. `~/.claude/agents/`
2. `<path>/.claude/agents/`

Agents are `*.md` files only (claude's agent convention has no `AGENT.md`-in-subdir form). Name = basename sans extension; description = frontmatter `description` field. Merge user + project, project wins. Return `[{name, description}]`.

### `clients/ios/src/Features/Chat/UI/ChatInputBarAutocompletePicker.swift`
Suggestions overlay rendered above `ChatInputBar` when `slashQuery != nil` or `atQuery != nil`.

```swift
struct ChatInputBarAutocompletePicker: View {
    enum Kind { case skill, agent }
    let kind: Kind
    let query: String
    let skills: [Skill]
    let agents: [Agent]
    let onSelect: (String) -> Void
    // horizontal ScrollView of ChatInputBarSkillPill / ChatInputBarAgentPill
    // filter by case-insensitive prefix match on name
    // cap to 8 results
    // glassEffect(.regular, in: Capsule()) on each pill, matching input chrome
}
```

Transition: `.move(edge: .bottom).combined(with: .opacity)`, driven by an `.animation(.easeInOut(duration: ThemeTokens.Duration.s), value: slashQuery != nil || atQuery != nil)` on the ChatInputBar side.

### `clients/ios/src/Features/Chat/UI/ChatInputBarSkillPill.swift`
One capsule pill: `Image(systemName: "slash.circle")` + `Text("/" + name)` in monospaced `ThemeTokens.Text.m`. Accent `ThemeColor.blue`. Tap fires `onSelect(name)`.

### `clients/ios/src/Features/Chat/UI/ChatInputBarAgentPill.swift`
Same shape, `Image(systemName: "at.circle")` + `Text("@" + name)`, accent `ThemeColor.orange`. Tap fires `onSelect(name)`.

## Files to modify

### `clients/ios/src/Features/Sessions/Logic/SessionService.swift`
Add two fetchers mirroring `generateTitleAndSymbol`:

```swift
static func skills(endpoint: Endpoint, sessionId: UUID, path: String) async -> [Skill]?
static func agents(endpoint: Endpoint, sessionId: UUID, path: String) async -> [Agent]?
```

Both call `HTTPClient.get(endpoint:path:)` with `path` query appended, decode the array via `JSONDecoder`, return nil on failure. (Check `HTTPClient.get` signature — if it doesn't accept a `query` param, build the query string into the path manually, mirroring other call sites.)

### `clients/ios/src/Features/Sessions/Logic/SessionActions.swift`
Add stateless setters so ChatInputBar (Chat feature) doesn't write `session.skills`/`session.agents` directly. Required by the "features don't reach into other features' models" rule:

```swift
@MainActor static func setSkills(_ skills: [Skill], for session: Session) { session.skills = skills }
@MainActor static func setAgents(_ agents: [Agent], for session: Session) { session.agents = agents }
```

### `clients/ios/src/Features/Chat/UI/ChatInputBar.swift`
1. Derive triggers from `draft` (mirrors cloude-main). Two computed props:
   ```swift
   private var slashQuery: String? {
       guard let slash = draft.lastIndex(of: "/") else { return nil }
       let after = draft[draft.index(after: slash)...]
       if after.contains(where: { $0 == " " || $0 == "\n" }) { return nil }
       if slash != draft.startIndex {
           let prev = draft[draft.index(before: slash)]
           if !prev.isWhitespace { return nil }
       }
       return String(after).lowercased()
   }
   private var atQuery: String? { /* same shape, trigger "@" */ }
   ```
   The "preceded by whitespace or start-of-string" guard is new (cloude-main skipped it) — prevents URLs (`https://foo`) or emails (`foo@bar`) from triggering.

2. Fetch skills/agents on appear (id-keyed, so switching sessions refetches):
   ```swift
   .task(id: session.id) {
       if let endpoint = session.endpoint, let path = session.path {
           if session.skills == nil,
              let s = await SessionService.skills(endpoint: endpoint, sessionId: session.id, path: path) {
               SessionActions.setSkills(s, for: session)
           }
           if session.agents == nil,
              let a = await SessionService.agents(endpoint: endpoint, sessionId: session.id, path: path) {
               SessionActions.setAgents(a, for: session)
           }
       }
   }
   ```

3. Render `ChatInputBarAutocompletePicker` in the outer `VStack` above the attachment strip so it floats just above the text field:
   ```swift
   if let q = slashQuery {
       ChatInputBarAutocompletePicker(kind: .skill, query: q,
           skills: session.skills ?? [], agents: [],
           onSelect: { replaceToken("/", with: "/\($0) ") })
   } else if let q = atQuery {
       ChatInputBarAutocompletePicker(kind: .agent, query: q,
           skills: [], agents: session.agents ?? [],
           onSelect: { replaceToken("@", with: "@\($0) ") })
   }
   ```

4. Add a private helper:
   ```swift
   private func replaceToken(_ trigger: Character, with replacement: String) {
       if let idx = draft.lastIndex(of: trigger) {
           draft = String(draft[..<idx]) + replacement
       }
   }
   ```

### `daemons/macos/src/Routing/Router.swift`
Register the two new routes next to the existing session-scoped GETs, following the existing `/sessions/:id/files` pattern 1:1. `RouteMatcher` already captures the `:id` param.

### `CLAUDE.md`
- Tick the new iOS files under `Features/Chat/UI/` (`ChatInputBarAutocompletePicker`, `ChatInputBarSkillPill`, `ChatInputBarAgentPill`) and update the `ChatInputBar` one-liner to mention autocomplete triggers.
- Update `SessionService.swift` and `SessionActions.swift` one-liners for the new methods.
- Add `SkillsHandler.swift` and `AgentsHandler.swift` entries under daemon `Handlers/` with route summaries. Drop the now-stale `skills`/`agents` bullets from the `SessionHandler` entry (one handler per concept).

## Files to reuse (no change)

- `Skill.swift`, `Agent.swift` — already `Codable`, decode straight from the wire.
- `Session.swift` `@Transient skills`/`agents` — already present.
- `HTTPClient.get`, `ChatService.send`, chat route — untouched.
- `ThemeTokens`, `ThemeColor`, `glassEffect` chrome — consumed for pill styling.

## Verification

1. **Daemon routes.** `curl -H "Authorization: Bearer <token>" http://localhost:8765/sessions/<uuid>/skills?path=<repo>` returns a JSON array that includes at least one entry from `~/.claude/skills/` and one from `<repo>/.claude/skills/`. Same shape for `/agents`. Project override: put same-named skill in both locations, verify project's description wins.
2. **Skill trigger.** Session with `endpoint+path` set, open chat, type `/`. Picker appears above the text field listing all skills. Type more characters; list filters by prefix. Tap a pill — text becomes `/<name> ` and picker dismisses.
3. **Agent trigger.** Type a word, space, `@`. Picker shows agents. Tap — splices `@<name> ` at the `@` position, preserves prefix text.
4. **False-trigger guard.** Type `https://example.com/` — no picker. Type `foo@bar` — no picker. Type `/` at start — picker shows.
5. **Close on send.** With picker open, tap send — picker dismisses with the cleared draft.
6. **Caching.** Open a session, let skills load, switch windows and back — no extra fetch. Switching to a different session triggers a fresh fetch (id-keyed `.task`).
7. **No-endpoint path.** Session without endpoint/path: ChatInputBar disabled, `session.skills` stays nil, typing `/` still computes `slashQuery` but picker renders zero pills (empty arrays).
