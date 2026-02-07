# Fix Table Column Alignment

Columns in markdown tables weren't aligned across rows — each row sized independently.

## Fix
Replaced `HStack`-based layout with SwiftUI `Grid` + `GridRow` in `MarkdownTableView`. Grid automatically measures the widest cell per column and applies uniform widths across all rows.

## Files
- `Cloude/Cloude/UI/MarkdownText+Blocks.swift`
