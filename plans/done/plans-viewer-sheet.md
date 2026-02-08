# Plans Viewer Sheet
<!-- priority: 10 -->
<!-- tags: files, ui -->
<!-- build: 56 -->

## Background
Plans live on the Mac filesystem under `plans/`. Currently the only way to browse them is via the file browser or asking Claude. Need a purpose-built UI to view plans from the phone — a button in the top-left toolbar next to the brain (memories) icon.

## Goals
- Browse all plans by stage from iOS
- Quick scanning: see title + preview without opening
- Full content view on tap
- Consistent with existing app patterns (sheets, toolbar buttons, dividers)

## UX Design

### Toolbar Button
Top-left toolbar in `CloudeApp.swift`, next to the brain icon:
```
[list.bullet.clipboard] | [brain]        ◉        [gearshape]
```
- Divider (height 20) between plans and brain buttons
- Icon: `list.bullet.clipboard` (or `checklist` — TBD)
- Tapping sends `getPlans` to the Mac agent, opens sheet

### Sheet Layout
```
┌─────────────────────────────────┐
│  ✕  Plans                       │
├─────────────────────────────────┤
│ [Active] [Testing] [Next] [Backlog] │  ← segmented picker
├─────────────────────────────────┤
│                                 │
│ ┌─────────────────────────────┐ │
│ │ agent-restart-reliability   │ │  ← filename as title
│ │ Fix Mac agent restart so it │ │  ← first ~5 lines of content
│ │ works reliably even when... │ │     as preview text
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ plans-viewer-sheet          │ │
│ │ Plans live on the Mac file  │ │
│ │ system under plans/...      │ │
│ └─────────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

- Segmented picker at top switches between stages
- Each stage shows its plans as cards
- Card: title (filename without .md), preview (first ~5-10 lines of body, skip the `# Title` line)
- Empty stages show a subtle "No plans" message
- Tapping a card navigates to full content view (rendered markdown, scrollable)
- Swipe left on a card → red trash button → deletes the plan file on the Mac agent
- Badge on the stage tabs showing count (e.g., "Active (1)")

### Full Plan View (on tap)
Tapping a plan card opens it via the existing `FilePathPreviewView` — same infra tool pills use for file links. The server response includes the full path (e.g., `plans/active/plans-viewer-sheet.md`) so we just pass it to the file preview sheet. No custom detail view needed.

## Server Protocol

### New message: `getPlans`
iOS sends `getPlans` → Mac agent reads the `plans/` directory tree.

### Response: `plans`
Mac agent sends back structured data:
```json
{
  "type": "plans",
  "stages": {
    "active": [
      { "filename": "plans-viewer-sheet.md", "title": "Plans Viewer Sheet", "content": "full markdown..." }
    ],
    "testing": [...],
    "next": [...],
    "backlog": [...]
  }
}
```

- Agent reads from the working directory's `plans/` folder
- Each plan: filename, title (extracted from first `# ` line), full content
- Only include stages that have files (or include all 4 with empty arrays)

### New message: `deletePlan`
iOS sends `deletePlan` with stage + filename → Mac agent deletes the file.
```json
{ "type": "deletePlan", "stage": "backlog", "filename": "some-feature.md" }
```
Agent removes `plans/{stage}/{filename}` and responds with updated plans (or a simple ack). iOS removes the card with animation.

## Files

### iOS App
- `CloudeApp.swift` — add plans button to toolbar, sheet state, `onPlans` handler
- `PlansSheet.swift` — **new** — sheet with segmented picker, plan cards, detail view
- `ConnectionManager+API.swift` — handle `plans` response
- `ConnectionEvent.swift` — add `.plans` event
- `CloudeShared/ServerMessage.swift` — add `getPlans` client message and `plans` server message

### Mac Agent
- `Cloude_AgentApp.swift` or command handler — handle `getPlans`, read filesystem, respond
- `CloudeShared/ServerMessage.swift` — shared message types

## Open Questions
- Icon: `list.bullet.clipboard` vs `checklist` vs `text.badge.checkmark`?
- Should we also show `done/` as a stage? Might be noisy with 80+ items. Probably skip.
- Should the segmented picker default to Active, or to whichever stage has items?
