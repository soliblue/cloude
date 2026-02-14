---
name: ui
description: Interact with any Mac app via Accessibility API. See UI elements, click buttons, type text, press keys. Zero dependencies — compiled Swift binary.
user-invocable: true
icon: hand.tap
aliases: [desktop, automation, mac-ui]
---

# Mac UI Automation Skill

Control any Mac app through the Accessibility API. See what's on screen, click buttons, type text, press keyboard shortcuts. Pure Swift, no dependencies.

## First-Time Setup

Grant Accessibility permission:
System Settings → Privacy & Security → Accessibility → enable for Terminal (and Cloude Agent).

This is the **one permission that unlocks everything** — after this, Cloude can interact with any app on the Mac.

## Binary Location

Pre-compiled at `.claude/skills/ui/cloude-ui`. To recompile:
```bash
cd .claude/skills/ui && swiftc -O -o cloude-ui cloude-ui.swift -framework Cocoa -framework ApplicationServices
```

## Commands

### List running apps
```bash
.claude/skills/ui/cloude-ui apps
```

### See UI elements of an app
```bash
.claude/skills/ui/cloude-ui see                      # Frontmost app
.claude/skills/ui/cloude-ui see "System Settings"     # Specific app
.claude/skills/ui/cloude-ui see "Safari"              # Any running app
```
Returns JSON array of interactive elements with id, role, label, position, and available actions.

### Click an element
```bash
.claude/skills/ui/cloude-ui click 5                   # Click element #5
.claude/skills/ui/cloude-ui click 12 "System Settings" # Click in specific app
```
Element IDs come from the `see` output. Always run `see` first to get current IDs.

### Type text
```bash
.claude/skills/ui/cloude-ui type "hello world"
```
Types into whatever field is currently focused.

### Press key combinations
```bash
.claude/skills/ui/cloude-ui press return              # Enter key
.claude/skills/ui/cloude-ui press cmd+s               # Save
.claude/skills/ui/cloude-ui press cmd+shift+n          # New window
.claude/skills/ui/cloude-ui press escape               # Escape
```

### List windows
```bash
.claude/skills/ui/cloude-ui windows
```

## Typical Workflow

1. `see "App Name"` → get element list with IDs
2. Find the element you want (button, text field, etc.)
3. `click <id>` → interact with it
4. `type "text"` → fill in fields
5. `press cmd+s` → keyboard shortcuts

## Security
- Only operates locally via macOS Accessibility API
- Accessibility permission is the single trust gate
- No data leaves the machine
- No screenshots stored (use the screenshot skill for that)
- Cannot interact with apps unless Accessibility is granted
