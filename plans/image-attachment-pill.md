# Image Attachment Pill UI

## Current State

Images attached to messages appear as a 36x36 thumbnail **inside** the input bar HStack, to the right of the text field. This creates visual clutter and takes space from the text input area.

**Current layout:**
```
[photo button] [text field................] [36x36 image] [send]
```

## Proposed Change

Move image attachment preview to a **pill above the input bar**, similar to how slash command autocomplete suggestions appear.

**Proposed layout:**
```
                        [📷 image.jpg  ✕]  ← pill row (only when image attached)
[photo button] [text field......................] [send]
```

## Pros

1. **More text input space** - image no longer competes with text field
2. **Consistent with autocomplete** - pills above input is an established pattern in the app
3. **Better visual hierarchy** - attachment is clearly separate from composition area
4. **Room for multiple attachments** - if we ever support multiple images, horizontal pills scale naturally
5. **Clearer dismissal** - X button on a pill is more discoverable than floating over a tiny thumbnail

## Cons

1. **Vertical space** - adds a row when image is attached (input bar grows taller)
2. **Animation complexity** - need smooth appear/disappear animation to avoid jarring layout shifts
3. **Slight refactor** - conditional layout changes, but isolated to one file

## Interaction with Slash Commands

The input bar's `body` is a `VStack(spacing: 0)` with this structure:
1. Pending audio banner (when unsent audio exists)
2. Skill parameter bar OR slash command suggestions (when typing `/`)
3. Input bar HStack

**Question**: What happens if user has an image attached AND types `/deploy`?

**Answer**: Stack both. Image pill row would be a separate conditional in the VStack:

```
[pending audio banner]        ← only when hasPendingAudio
[image attachment pill]       ← only when selectedImageData != nil  (NEW)
[slash command suggestions]   ← only when typing /command
[input bar]
```

This works because:
- Image pill is small (one item, right-aligned)
- Slash commands are horizontal scroll
- Both being visible is rare but valid
- Stacking keeps them visually distinct

## Design Details

### Pill Design
- Rounded rectangle (similar to `SkillPill`)
- Small thumbnail (24x24 or 28x28) on left
- Filename or "Image" text in middle
- X button on right
- Background: semi-transparent gray or accent-tinted
- Positioned in a HStack with `.trailing` alignment (right side above input)

### Animation
- Use `matchedGeometryEffect` or simple `transition(.move(edge: .bottom).combined(with: .opacity))`
- Spring animation to match existing UI feel

### Interaction
- Tap pill: could show full-size preview (optional enhancement)
- Tap X: remove attachment
- Swipe gesture on input bar should still clear image (existing behavior)

## Files to Change

| File | Changes |
|------|---------|
| `Cloude/Cloude/UI/GlobalInputBar.swift` | Main change - move image from HStack to pill row above |

That's it. Single file change. The image state (`selectedImageData`) and all the sending logic stays the same - we're just moving where the preview renders.

### Code Sketch

```swift
// In GlobalInputBar.swift body, insert BEFORE the slash command suggestions block:

VStack(spacing: 0) {
    // Pending audio banner (existing)
    if audioRecorder.hasPendingAudio ... { ... }

    // NEW: Image attachment pill
    if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
        HStack {
            Spacer()
            ImageAttachmentPill(
                image: uiImage,
                onRemove: { selectedImageData = nil }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // Skill parameter bar OR slash commands (existing)
    if let skill = selectedSkillCommand ... { ... }
    else if !filteredCommands.isEmpty { ... }

    // Input bar HStack (existing, minus the image thumbnail)
    ZStack { ... }
}
```

Then remove the image preview from inside the input HStack (lines 211-225).

## Decision

Recommend proceeding - it's a focused change with clear UX benefits. The vertical space tradeoff is minimal (only visible when image attached) and matches existing patterns.
