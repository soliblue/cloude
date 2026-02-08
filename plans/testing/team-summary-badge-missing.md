# Team Summary Badge Not Appearing

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
