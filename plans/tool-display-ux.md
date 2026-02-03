# Tool Display UX Plan

Better rendering and interaction for tool call pills.

## Current State

- `InlineToolPill` in `ChatView+MessageBubble.swift` - basic pill with tool name + truncated input
- `ToolGroupView` in `StreamingMarkdownView.swift` - horizontal scroll of pills
- `parentToolId` stored but children never rendered
- No icons, just text labels
- Tap opens file preview for file-related tools, nothing for others

## Goal

- Custom icons for each tool type
- Tap to expand details (liquid glass popover)
- Show nested tool calls (Task → agent tools)
- Parse `&&` chains into linked pills
- Real-time progress updates

## Tool Icons (SF Symbols)

```swift
func iconForTool(_ name: String) -> String {
    switch name {
    case "Read": return "doc.text"
    case "Write": return "doc.badge.plus"
    case "Edit": return "pencil.line"
    case "Bash": return "terminal"
    case "Grep": return "magnifyingglass"
    case "Glob": return "folder.badge.magnifyingglass"
    case "Task": return "person.2"
    case "WebFetch": return "globe"
    case "WebSearch": return "magnifyingglass.circle"
    case "TodoWrite": return "checklist"
    case "Memory": return "brain"
    default: return "gear"
    }
}
```

## Tool Detail Popover

Tap pill → show `.ultraThinMaterial` sheet with:
- Full tool name + icon
- Complete input (not truncated)
- Output/result if available
- Duration if available
- For files: syntax-highlighted preview
- For Bash: command output

## Nested Tool Hierarchy

When tool has children (`parentToolId` matches):
- Show disclosure indicator on parent pill
- Tap to expand inline, showing child tools indented
- Collapse to hide

```swift
struct ToolCallWithChildren {
    let tool: ToolCall
    var children: [ToolCall]
    var isExpanded: Bool
}

func buildToolHierarchy(_ tools: [ToolCall]) -> [ToolCallWithChildren] {
    let topLevel = tools.filter { $0.parentToolId == nil }
    return topLevel.map { parent in
        let children = tools.filter { $0.parentToolId == parent.toolId }
        return ToolCallWithChildren(tool: parent, children: children, isExpanded: false)
    }
}
```

## Chained Command Parsing

For Bash with `&&`:
```swift
func parseChainedCommands(_ input: String) -> [String] {
    // Split on && but respect quotes
    // "cd /foo && git status && echo done" → ["cd /foo", "git status", "echo done"]
}
```

Display as linked pills with connector line between them.

## Files to Modify

- `Cloude/Cloude/UI/ChatView+MessageBubble.swift` - InlineToolPill icon + tap handler
- `Cloude/Cloude/UI/StreamingMarkdownView.swift` - ToolGroupView hierarchy support
- New: `Cloude/Cloude/UI/ToolDetailSheet.swift` - popover content
- New: `Cloude/Cloude/Services/BashCommandParser.swift` - already exists, extend for chains

## Phases

### Phase 1: Icons
- Add SF Symbol icons to pills
- Simple mapping by tool name

### Phase 2: Detail Popover
- Tap pill → sheet with full details
- File preview for Read/Write/Edit
- Command output for Bash

### Phase 3: Nested Tools
- Build hierarchy from parentToolId
- Expandable parent pills
- Indented child rendering

### Phase 4: Chained Commands
- Parse && in Bash input
- Render as connected pills

## Open Questions

- Store tool output for later viewing? Currently not persisted
- How to show real-time progress? Need streaming updates per-tool
- Should nested tools auto-expand or start collapsed?
