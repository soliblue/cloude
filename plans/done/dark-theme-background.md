# Dark Theme Background & Ocean Palette Consistency

**Status**: Testing
**Changed**: Colors.swift, ConversationView+Components.swift, SettingsView.swift, ConversationSearchSheet.swift, WindowEditForm.swift

## What
1. Added `.background(Color.oceanBackground)` to `ChatMessageList` — empty conversation screen was showing pure system black instead of ocean navy
2. Bumped all ocean dark palette values to be more visibly blue:
   - `oceanBackground`: `0x111D2B` → `0x152233`
   - `oceanSecondary`: `0x1A2332` → `0x1C2B3D`
   - `oceanSurface`: `0x243044` → `0x263750`
   - `oceanTertiary`: `0x1F2B3D` → `0x223350`
   - `oceanFill`: `0x2A3A50` → `0x2E4058`
3. Added `.listRowBackground(Color.oceanSecondary)` to every Settings section — rows had default system gray/glassy material
4. Replaced `.regularMaterial` with `Color.oceanSecondary` in ConversationSearchSheet (card backgrounds) and WindowEditForm (symbol button, name field, folder picker, cost limit, conversation list)
5. Added ocean nav bar styling and background to ConversationSearchSheet

## Why
- Empty conversation screen showed pure black (system default on OLED)
- `.regularMaterial` created a glassy gray look that clashed with the ocean blue theme across Settings, search sheet, and window edit form

## Test
- **Dark mode**: All sheets (Settings, Search, Window Edit) should feel cohesive ocean blue — no gray/glassy material
- **Light mode**: Should still look correct (ocean colors map to system defaults in light)
- **Empty conversation**: Blue-tinted background behind pixel art, not black
- **Visual hierarchy**: Background → secondary → tertiary still distinct
