# Disable Environments

## Problem
No way to temporarily disable an environment without deleting it. Users may want to keep the config but not auto-connect.

## Proposed UX
Toggle in the top bar of each EnvironmentCard. When disabled:
- Card dims (lower opacity)
- Status shows "Disabled" in gray
- Connect button hidden
- Environment skipped during auto-connect

## Files to Change
- `Environment.swift` - add `isEnabled: Bool` field
- `SettingsView+Environments.swift` - toggle + dimmed card state
- `ConnectionManager.swift` - skip disabled environments
