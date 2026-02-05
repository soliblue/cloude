# Memory UI Plan

Structured memory display instead of raw markdown rendering.

## Current State

- Memories stored as markdown in `CLAUDE.md` (project) and `CLAUDE.local.md` (local)
- Sections denoted by `## Heading` with bullet points or paragraphs underneath
- `MemoryView.swift` renders raw markdown text
- `cloude memory` command appends to sections

## Goal

Display memories as structured cards with:
- Title (section heading)
- Individual memory items (not raw text blobs)
- Collapsible groups
- Drag-and-drop reordering
- Visual distinction local vs project

## Data Model

```swift
struct MemoryItem: Identifiable {
    let id: UUID
    var content: String
    var metadata: Date?  // when added, if parseable
}

struct MemorySection: Identifiable {
    let id: UUID
    var title: String
    var items: [MemoryItem]
    var isCollapsed: Bool
}

struct MemoryDocument {
    var sections: [MemorySection]
    let source: MemorySource  // .local or .project
}
```

## Parsing Strategy

1. Split markdown by `## ` to get sections
2. Within each section, split by `- ` for bullet items
3. Each bullet becomes a `MemoryItem`
4. Non-bullet paragraphs become single items
5. Preserve ordering for round-trip (parse → edit → save)

## UI Components

### MemoryCardView
- Section header with collapse chevron
- List of `MemoryItemView` cards
- Drag handle for reordering sections

### MemoryItemView
- Rounded card with content text
- Swipe to delete
- Long press to edit
- Drag to reorder within section or move to other section

### MemoryEditorSheet
- Text field for editing item content
- Option to move to different section
- Delete button

## Files to Modify

- `Cloude/Cloude/UI/MemoryView.swift` - replace raw markdown with structured view
- New: `Cloude/Cloude/Models/MemoryDocument.swift` - data model
- New: `Cloude/Cloude/Services/MemoryParser.swift` - markdown ↔ structured parsing

## Phases

### Phase 1: Read-only structured display
- Parse markdown into sections/items
- Display as collapsible cards
- No editing yet

### Phase 2: Editing
- Add/edit/delete items
- Reorder within sections
- Save back to markdown

### Phase 3: Organization
- Drag items between sections
- Create new sections
- Merge sections

## Open Questions

- How to handle freeform text that isn't bullet points?
- Should we support nested lists (sub-items)?
- How to preserve markdown formatting within items (bold, code, links)?
