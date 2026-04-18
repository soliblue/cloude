---
title: "Fix Table Column Alignment"
description: "Fixed markdown table column alignment by replacing HStack with SwiftUI Grid for uniform column widths."
created_at: 2026-02-07
tags: ["markdown", "ui"]
icon: tablecells
build: 44
---


# Fix Table Column Alignment {tablecells}
Columns in markdown tables weren't aligned across rows — each row sized independently.

## Fix
Replaced `HStack`-based layout with SwiftUI `Grid` + `GridRow` in `MarkdownTableView`. Grid automatically measures the widest cell per column and applies uniform widths across all rows.

## Files
- `Cloude/Cloude/UI/MarkdownText+Blocks.swift`
