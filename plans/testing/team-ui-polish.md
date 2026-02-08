# Team UI Polish {person.3.sequence.fill}
<!-- priority: 2 -->
<!-- tags: ui, teams -->
<!-- build: 56 -->

> Three improvements to team dashboard: compact orb info in toolbar row, show team lead, and inline messages per teammate.

## 1. Compact Orb Info — Status in Toolbar Row

Currently the orb shows a pulsing circle (working), half-opacity (idle), and status text separately in the detail sheet. This info could be shown inline next to the teammate name in the orb row itself, saving vertical space and making status visible at a glance.

**Approach:**
- Add a small status indicator below the orb name (or next to it)
- Use the existing color dot pattern from `TeamDashboardSheet.statusDot`
- Keep the orb circle but integrate model badge + status into the same compact space
- Consider a single-line layout: `[orb] name · S · Active` instead of stacking vertically

## 2. Show Team Lead

The team lead (the main conversation agent — "me") is not shown anywhere in the team UI. The `teammates` array only contains spawned members, not the lead.

**Approach:**
- Add team lead as the first entry in TeamDashboardSheet
- Use a distinct visual treatment (e.g., crown icon, "Lead" label, or different orb style)
- Data source: the lead's info comes from `config.json` which has the lead in `members[0]`
- In the orb overlay, the lead doesn't need an orb (you're already looking at the lead's conversation), but the dashboard should show them for completeness

## 3. Messages Inline Per Teammate

Currently the dashboard shows teammates in one section and messages in a separate section below a divider. This means you have to mentally match messages to teammates.

**Approach:**
- Show each teammate's messages directly below their row in the dashboard
- Expand/collapse: tap a teammate row to show/hide their message history
- Use `mate.messageHistory` (already tracked, up to 50 messages)
- Remove the separate "recent messages" section at the bottom
- Each message: small timestamp + text, indented under the teammate row

## Files
- `Cloude/Cloude/UI/TeamOrbsOverlay.swift` — compact status in orb row
- `Cloude/Cloude/UI/TeamBannerView.swift` — team lead entry + inline messages
- `Cloude/CloudeShared/Sources/CloudeShared/Models/TeamTypes.swift` — may need lead info
