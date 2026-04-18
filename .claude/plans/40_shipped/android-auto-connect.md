---
title: "Android Auto-Connect"
description: "Auto-connect to environment when selecting it."
created_at: 2026-04-05
tags: ["android", "connection"]
build: 125
icon: wifi
---
# Android Auto-Connect {wifi}


## Desired Outcome
When selecting an environment in the folder picker or environment switcher, automatically attempt connection if not already connected. Show connecting state with timeout.

## iOS Reference Architecture

### Components
- `EnvironmentFolderPicker.swift` - pendingConnectionEnvId state, auto-connect on selection

### Android implementation notes
- In environment/folder picker, check if selected environment is connected
- If not, trigger `connectionManager.connectEnvironment()` automatically
- Show connecting indicator (spinner or progress)
- 10-second timeout, fall back to disconnected state on failure

**Files (iOS reference):** EnvironmentFolderPicker.swift
