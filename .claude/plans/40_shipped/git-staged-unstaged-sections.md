---
title: "Git Changes: Staged/Unstaged Sections + Deleted Files"
description: "Split git changes into staged/unstaged sections with proper deleted file handling and cached diffs."
created_at: 2026-03-15
tags: ["ui", "git"]
icon: list.bullet.indent
build: 86
---


# Git Changes: Staged/Unstaged Sections + Deleted Files {list.bullet.indent}
Split the git changes view into two sections (staged vs working tree) and handle deleted files properly.

## Background

`git status --porcelain` outputs 2-char codes: `XY path` where X=index status, Y=working tree status. Currently `parseStatus` trims whitespace, losing the distinction (` M` becomes `M`, ` D` becomes `D`). The UI shows a flat list with no staging context. Deleted files open file preview which fails since the file doesn't exist on disk.

## Goals
- Show staged and working tree changes as separate list sections
- Tapping staged files diffs with `--cached`, working tree files diff without
- Deleted files open diff view showing the removal (not file preview)
- Handle compound statuses like `MM` (appears in both sections)

## Approach

### 1. Preserve 2-char status in parsing (`GitService.swift`)
Stop trimming whitespace. Keep full XY code and split into two entries when both X and Y are meaningful.

### 2. Add staging-aware model (`GitTypes.swift`)
Add a `staged` bool to `GitFileStatus` so the same file can appear twice (once staged, once unstaged). Update `id` to include staging context. Add `isDeleted` computed property.

### 3. Split list into sections (`GitChangesView.swift`)
Filter files into staged/unstaged arrays. Show "Staged" section header only when staged files exist. Same `GitFileRow` component, just grouped.

### 4. Diff routing (`GitDiffView.swift`)
Pass `staged` bool through. Use `git diff --cached` for staged files, `git diff` for unstaged. Both work for deletions.

### 5. Status display (`GitChangesView+Components.swift`, `GitDiffView.swift`)
Handle single-char statuses (`M`, `A`, `D`, `R`) since each entry now represents one side (index or working tree), not the raw XY pair.

## Files
- `Cloude/Cloude Agent/Services/GitService.swift` - parseStatus splitting
- `Cloude/CloudeShared/Sources/CloudeShared/Models/GitTypes.swift` - model changes
- `Cloude/Cloude/UI/GitChangesView.swift` - sectioned list
- `Cloude/Cloude/UI/GitChangesView+Components.swift` - status colors/icons (minor)
- `Cloude/Cloude/UI/GitDiffView.swift` - staged diff flag

## UI Mockup
```
┌─────────────────────────────────┐
│  main         1 staged · 3 changed │
├─────────────────────────────────┤
│  STAGED                         │
│  M  GitDiffView.swift           │
├─────────────────────────────────┤
│  CHANGES                        │
│  M  GitDiffView.swift           │
│  M  FilePreviewView+Content.swift│
│  D  FilePreviewView+DiffSheet…  │
│  M  GitDiffView+Components.swift│
└─────────────────────────────────┘
```
