# Code Block Toolbar Enhancements

## Summary
Enhance `CodeBlock` in chat with a proper toolbar: always show copy button (even without language), add word wrap toggle and line numbers toggle. Global defaults in Settings, per-snippet overrides via toolbar buttons.

## Changes

### 1. Settings - Add line numbers toggle
**File**: `SettingsView.swift`
- Add `@AppStorage("showCodeLineNumbers")` (default: true)
- Add toggle row next to existing "Wrap Code Lines"

### 2. CodeBlock - Full toolbar redesign
**File**: `MarkdownText+Blocks.swift`
- Always show toolbar header (not just when language is known)
- Show language label on the left (if known), otherwise just show toolbar
- Add three toolbar buttons on the right:
  1. Line numbers toggle (per-snippet `@State`, initialized from `@AppStorage`)
  2. Word wrap toggle (per-snippet `@State`, initialized from `@AppStorage`)
  3. Copy button (always visible)
- Use `Divider().frame(height: 14)` between buttons
- Implement word wrap: when ON, remove horizontal ScrollView, use `.fixedSize(horizontal: false, vertical: true)`. When OFF, keep horizontal scroll
- Implement line numbers: when ON, prefix each line with line number column
- Single-line code: hide line numbers regardless, hide wrap toggle (irrelevant)
- Local `@State` overrides don't write back to `@AppStorage` - they're per-snippet only

### 3. Behavior
- **Word wrap default**: from `@AppStorage("wrapCodeLines")` (already exists, default true)
- **Line numbers default**: from `@AppStorage("showCodeLineNumbers")` (new, default true)
- **Toolbar buttons**: toggle only for this snippet, don't change the global setting
- **Single-line snippets**: no toolbar header at all (just the code, clean)
