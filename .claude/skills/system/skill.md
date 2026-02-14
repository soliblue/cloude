---
name: system
description: Mac system info — battery, CPU, disk, memory, wifi, uptime, display status. All shell commands, no dependencies.
user-invocable: true
icon: desktopcomputer
aliases: [sysinfo, battery, disk, mac]
---

# System Info Skill

Quick system diagnostics via built-in macOS commands. No dependencies, no permissions.

## Usage

```bash
bash .claude/skills/system/sysinfo.sh              # Full overview
bash .claude/skills/system/sysinfo.sh battery       # Battery only
bash .claude/skills/system/sysinfo.sh disk          # Disk usage only
bash .claude/skills/system/sysinfo.sh wifi          # Wifi info only
bash .claude/skills/system/sysinfo.sh memory        # RAM usage only
bash .claude/skills/system/sysinfo.sh display       # Display status
```

## Use Cases
- "How's the laptop doing?"
- "Battery level?"
- "Am I running low on disk?"
- Heartbeat: include system health in status checks
