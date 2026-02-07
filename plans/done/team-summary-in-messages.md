# Team Summary in Saved Messages

## Problem
When a team finishes, the banner and orbs disappear and there's no trace that the response was team-built. Scrolling back through history, you can't tell which messages had a team behind them.

## Solution
Save a `TeamSummary` on each assistant `ChatMessage` when a team is active. Shows as a tappable capsule badge (overlapping colored circles + team name) in the message footer alongside cost/duration stats. Tapping opens the team dashboard with member details.

During streaming: banner + orbs at top, exactly like before — they disappear when team deletes.
After save: team info persists in the message footer permanently.

## Files Changed

- **Conversation.swift**: `TeamSummary` struct + `teamSummary` field on `ChatMessage`
- **ConversationStore+Messaging.swift**: Capture team data in `finalizeStreamingMessage`
- **ChatView+MessageBubble.swift**: `TeamSummaryBadge` view in footer, sheet to open dashboard
