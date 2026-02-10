# Team Summary Badge Not Appearing
<!-- priority: 3 -->
<!-- tags: teams -->
<!-- build: 56 -->

Team summary badges should show in saved messages after a team finishes, but they're missing.

## Problem

Race condition between `teamDeleted` and run completion:

1. Team finishes → Mac agent sends `teamDeleted` WebSocket message
2. iOS receives it → immediately clears `output.teamName` and `output.teammates`
3. Run finishes → `finalizeStreamingMessage` is called
4. It tries to capture team data from `output.teamName`/`output.teammates` → already nil/empty
5. Result: `teamSummary` is nil on saved messages → badge never appears

## Desired Outcome

Team summary badge (overlapping colored circles + team name) appears in message footer for any message that was built with a team, even after the team is deleted.

## Current Code

`ConnectionManager+API.swift:200-206`:
```swift
private func handleTeamDeleted(conversationId: String?) {
    if let id = targetConversationId(from: conversationId) {
        let o = output(for: id)
        o.teamName = nil
        o.teammates = []
    }
}
```

`ConversationStore+Messaging.swift:19-27`:
```swift
var teamSummary: TeamSummary?
if let teamName = output.teamName, !output.teammates.isEmpty {
    teamSummary = TeamSummary(teamName: teamName, members: ...)
}
```

## Solution Implemented

**Snapshot approach** - capture team data before clearing it:

1. Added `teamSnapshot: (name: String, members: [TeammateInfo])?` to `ConversationOutput`
2. Modified `handleTeamDeleted` to snapshot team data before clearing:
   ```swift
   if let teamName = o.teamName, !o.teammates.isEmpty {
       o.teamSnapshot = (name: teamName, members: o.teammates)
   }
   o.teamName = nil
   o.teammates = []
   ```
3. Modified `finalizeStreamingMessage` to use snapshot as fallback when live data is cleared
4. Clear snapshot in `reset()`

Now team data persists through the deletion event and is available when message is finalized.

## Files Changed

- `Cloude/Cloude/Services/ConnectionManager.swift` - added teamSnapshot property, clear it in reset()
- `Cloude/Cloude/Services/ConnectionManager+API.swift` - snapshot before clearing in handleTeamDeleted
- `Cloude/Cloude/Models/ConversationStore+Messaging.swift` - use snapshot as fallback

## Codex Review

**Findings (highest risk first)**
1. `teamSnapshot` on `ConversationOutput` looks global, not run-scoped. If a new run/team starts before prior `finalizeStreamingMessage`, snapshot data can bleed into the wrong saved message. This is the main correctness risk.
2. Clearing snapshot in `reset()` is too coarse for race-heavy flows. If `reset()` timing changes (reconnect, view switch, retry), you can lose valid snapshot data before finalize, or keep stale data too long.
3. Fallback logic can mask state bugs. If `finalizeStreamingMessage` silently prefers snapshot when live fields are empty, you may hide unexpected ordering issues and make debugging harder.
4. Potential mutability/copy issue: ensure teammates are deep-copied into snapshot, not referencing a collection that can still mutate after deletion handling.
5. Missing idempotency guard: duplicate `teamDeleted` events may overwrite snapshot with empty/default data depending on handler order.

**Missing considerations**
1. Multi-run concurrency: what keys correlate snapshot to the specific streaming message/run (`runId`, `messageId`)?
2. Non-team runs: ensure snapshot fallback is only used when the finalized run is known to be team-generated.
3. Reconnect/replay behavior: if WS replays events after reconnect, does snapshot lifecycle still behave correctly?

**Suggested improvements**
1. Make snapshot run-scoped (`[runId: TeamSnapshot]`) rather than a single optional.
2. Consume-and-clear snapshot at finalize for that run only; avoid `reset()` as primary cleanup.
3. Add explicit precedence + telemetry: "live data used" vs "snapshot used", with warning logs on fallback.
4. Keep handler idempotent: ignore `teamDeleted` if already snapshotted for that run.

**Tests to add**
1. `teamDeleted` before finalize => badge persists.
2. Finalize before `teamDeleted` => badge persists from live data.
3. Two overlapping runs with different teams => no cross-contamination.
4. Duplicate `teamDeleted` => stable snapshot.
5. Reconnect/replay ordering => correct badge outcome.
