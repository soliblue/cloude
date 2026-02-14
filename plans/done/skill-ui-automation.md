# Mac UI Automation Skill {hand.tap}
<!-- priority: 9 -->
<!-- tags: skill, automation, accessibility -->

> Interact with any Mac app via the Accessibility API. See the screen, click buttons, type text, navigate menus. Zero dependencies — pure Swift compiled with `swiftc`. Gives Cloude hands on the desktop.

## Approach
Small Swift CLI (~200 lines) using:
- `CGWindowListCreateImage` for screenshots (already built into macOS)
- `AXUIElement` API for reading UI trees, clicking, typing (built into macOS)
- Compile with `swiftc` — no Xcode project, no brew, no packages

## Commands
- `cloude-ui see` — screenshot + JSON list of interactive elements (id, label, role, position)
- `cloude-ui click <id>` — click element by ID
- `cloude-ui type "text"` — type into focused field
- `cloude-ui press <key>` — press key combo (e.g. cmd+s)
- `cloude-ui list-windows` — list all windows with app names

## Chicken-and-Egg
Needs Accessibility permission (System Settings → Privacy → Accessibility). One-time manual grant. After that, can self-grant other permissions (Screen Recording, Automation) by navigating System Settings UI programmatically.

## Use Cases
- Grant Calendar/Mail/Screenshot permissions without being at laptop
- Interact with apps that don't support AppleScript
- Fill web forms, navigate complex UIs
- Read on-screen content from any app
- True desktop automation — the universal skill

## Security
- Only runs locally on the Mac
- Accessibility permission is the single trust gate
- No data leaves the machine

**Files:** `.claude/skills/ui/`, single Swift file compiled to binary
