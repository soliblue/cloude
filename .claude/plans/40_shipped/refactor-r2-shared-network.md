---
title: "Refactor R2: Move NetworkHelper to CloudeShared"
description: "Moved duplicated NetworkHelper into the CloudeShared package for both targets to use."
created_at: 2026-02-07
tags: ["refactor"]
icon: network
build: 43
---


# Refactor R2: Move NetworkHelper to CloudeShared
## Status: Active

## Problem
`NetworkHelper` is duplicated across both targets:
- `Cloude/Cloude/Utilities/Network.swift`
- `Cloude/Cloude Agent/Utilities/Network.swift`

Nearly identical implementations. Both used for IP address display.

## Fix
- Move to `CloudeShared/Sources/CloudeShared/Extensions/NetworkHelper.swift`
- Delete both target-specific copies
- Both targets already import CloudeShared
