---
title: "Single Smart Reply"
description: "Show only one smart reply suggestion instead of two — cleaner, less noisy, more opinionated."
created_at: 2026-02-08
tags: ["input", "ui"]
icon: text.bubble
build: 53
---


# Single Smart Reply
## Problem
Two suggestions take up vertical space and add decision fatigue. A single confident recommendation feels more like a smart assistant and less like a menu.

## Changes
- Limit smart reply suggestions to 1 instead of 2
- The agent should pick the single best suggestion, not return multiple

## Files
- Wherever suggestions are requested/received — trim to 1
- `GlobalInputBar+Components.swift` — may need layout adjustment for single bubble
