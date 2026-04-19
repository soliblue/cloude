---
title: "Faster Connection Timeout"
description: "Reduced connection timeout from 60s to 10s for unreachable environments."
created_at: 2026-03-12
tags: ["connection"]
icon: bolt
build: 86
---


# Faster Connection Timeout
## Problem
Unreachable environments show "Connecting..." for ~60 seconds (iOS default TCP timeout) before failing.

## Solution
Set `timeoutIntervalForRequest = 10` on the URLSession configuration. Unreachable hosts now fail in 10 seconds instead of 60.

## File Changed
- `EnvironmentConnection.swift` - `reconnect()` method
