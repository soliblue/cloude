---
title: "Sticky Tasks Above Input Bar"
description: "Keep current TodoWrite progress visible above the input bar during streaming."
created_at: 2026-03-21
tags: ["ui"]
icon: checklist
build: 103
---


# Sticky Tasks Above Input Bar
When Claude is working and has active tasks (TodoWrite with incomplete items), there's no persistent visibility into progress. You have to scroll up or tap a tool pill to see what's being worked on. During streaming this is especially annoying since new messages push the task list out of view.

## Desired Outcome

A compact task strip sits above the GlobalInputBar whenever there are incomplete tasks. Shows current progress (e.g. "3/7") with the active/in-progress task name visible. Updates live as TodoWrite calls come in. Collapses automatically when all tasks complete (or after a short delay). Tappable to expand full task list.

Needs to be smart about updates: TodoWrite gets called repeatedly with the full list each time, so the view should diff against the previous state rather than re-rendering from scratch (avoid flicker/animation resets during streaming).

**Files:** `GlobalInputBar.swift`, `ToolDetailSheet+Content.swift` (reuse `todoSection`), `ToolCallLabel.swift` (reuse parsing), `MainChatView.swift` (state threading), `Conversation.swift` (latest todo extraction)
