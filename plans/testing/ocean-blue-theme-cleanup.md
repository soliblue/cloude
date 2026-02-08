# Ocean Blue Theme Cleanup

## Status: Testing

## Summary
Made the dark theme more bluish (Material Ocean style) instead of grayish/black, and removed white backgrounds from pixel art empty state characters.

## Changes

### Colors.swift — New ocean color tokens
- `oceanBackground`: `0x0F111A` → `0x0F1923` (darker navy with blue tint)
- `oceanSecondary`: `0x1B1E2B` → `0x1A2332` (blue-shifted secondary)
- `oceanSurface`: `0x292D3E` → `0x243044` (blue-shifted surface)
- `oceanGray6`: `0x1B1E2B` → `0x1A2332`
- `oceanGroupedSecondary`: same shift
- **New**: `oceanTertiary` (`0x1F2B3D`) — replaces `tertiarySystemGroupedBackground`
- **New**: `oceanFill` (`0x2A3A50`) — replaces `systemFill` / `quaternarySystemFill`
- **New**: `oceanSystemBackground` (`0x0F1923`) — replaces `Color(.systemBackground)`

### System color replacements (grayish → ocean bluish)
- `MemoriesSheet.swift` — section/item card backgrounds
- `GlobalInputBar.swift` — text field background
- `ConversationView+Components.swift` — scroll-to-bottom button
- `CSVTableView.swift` — header and alternating row backgrounds
- `FilePathPreviewView+Content.swift` — file viewer backgrounds
- `TeamBannerView.swift` — message history background
- `QuestionView.swift` — question card and option backgrounds
- `MarkdownText+Blocks.swift` — blockquote accent bar

### Pixel art characters — background removal
- Removed white backgrounds from all 7 characters (baby, chef, grandpa, cowboy, wizard, ninja, artist)
- Used flood-fill from edges to make outer background transparent
- Cloud bodies preserved as part of character design
- Now works across both light and dark themes

## Test
- [ ] Dark mode looks bluish, not grayish/black
- [ ] Light mode unchanged
- [ ] Empty conversation characters display correctly on both themes
- [ ] Memories sheet cards have blue tint
- [ ] Input bar field background has blue tint
- [ ] CSV tables, file previews, question cards all blue-tinted
- [ ] Scroll-to-bottom button looks correct
