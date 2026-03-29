# Android Memories View {brain}
<!-- priority: 12 -->
<!-- tags: android, memories -->

> View and browse CLAUDE.local.md memory sections in a sheet.

## Desired Outcome
Display memory sections parsed from CLAUDE.local.md. Section cards with title, icon, and expandable content. Refresh from agent on demand.

## iOS Reference Architecture

### Data flow
1. Server sends `ServerMessage.Memories` containing raw markdown text of CLAUDE.local.md
2. `MemoryParser.swift` parses markdown into hierarchical `MemoryDocument`:
   - Splits by `## Section {sf.symbol}` headers into `ParsedMemorySection`
   - Each section has subsections from `### Subsection {sf.symbol}` headers
   - Individual bullet points become `MemoryItem` with content and optional timestamp
3. `MemoryDocument` contains source (local vs project) and list of sections

### UI structure
- `CloudeApp+MemoriesSheet.swift` - modal sheet with two tabs: Personal (CLAUDE.local.md) and Project (CLAUDE.md)
- `CloudeApp+MemoryCards.swift` - section cards with SF Symbol icon from header, title, expand/collapse, subsection list, individual memory items

### Android implementation notes
- Parse `## Section {sf.symbol}` headers, map SF Symbol names to Material Icons
- Use `ModalBottomSheet` with `LazyColumn` for sections
- `ServerMessage.Memories` already handled in message parsing (just needs UI)
- Expandable cards with `AnimatedVisibility` for section content

**Files (iOS reference):** CloudeApp+MemoriesSheet.swift, CloudeApp+MemoryCards.swift, MemoryParser.swift, MemoryDocument.swift
