---
title: "Android Markdown Enhancements v2"
description: "XML tree rendering, file path pills, and slash command pills in message bubbles."
created_at: 2026-04-02
tags: ["android", "markdown", "ui"]
build: 125
icon: text.badge.star
---
# Android Markdown Enhancements v2


## Context

iOS markdown rendering has three features Android lacks:
1. **XML tree blocks** - When Claude outputs XML-tagged content, iOS parses it into an AST and renders as an expandable/collapsible tree with syntax coloring
2. **File path pills** - Absolute paths (starting with `/`) render as tappable colored chips that open the file in preview
3. **Slash command pills** - Messages containing `/command` or `<command-name>` tags render as styled pills showing command icon, name, and args

## Scope

### XML Tree Rendering
- Detect XML blocks in markdown output (fenced or inline)
- Parse into node tree (element name, attributes, children, text content)
- Render as expandable tree with indentation and syntax coloring
- Tap to expand/collapse branches

### File Path Pills
- Regex-detect absolute file paths in assistant messages
- Render as tappable AnnotatedString spans with accent background
- Tapping opens file preview sheet (or file browser if directory)

### Slash Command Pills
- Detect `/command args` patterns at message start
- Render as styled chip showing command icon + name + args
- Match against known slash commands for icon resolution

## Dependencies

- File preview system (for path pill tap handling)
- Slash command registry (for icon mapping)
