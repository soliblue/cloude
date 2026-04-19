---
title: "Fix Tool Pill Height and Heredoc Parsing"
description: "Fixed tool pill vertical stretching and heredoc commands being split into separate labels."
created_at: 2026-03-15
tags: ["ui", "tool-pill"]
icon: capsule
build: 86
---


# Fix Tool Pill Height and Heredoc Parsing
Two fixes for InlineToolPill display bugs.

## Changes

### 1. Heredoc parsing (BashCommandParser.swift)
Commands containing `<<` (heredocs) are now treated as single commands instead of being split on `;`, `|`, `&&`. Previously, a `git commit -m "$(cat <<'EOF'...EOF)"` would split the heredoc JS/text content on semicolons, showing `const`, `function`, `let` as separate chained command labels.

### 2. Pill height constraint (InlineToolPill.swift)
- Added `.fixedSize(horizontal: false, vertical: true)` to pill container to prevent vertical stretching
- Added `.lineLimit(1)` to chained command Text views to prevent wrapping

**Files:** `BashCommandParser.swift`, `InlineToolPill.swift`
