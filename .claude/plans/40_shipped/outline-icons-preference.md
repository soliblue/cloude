---
title: "Prefer Outline Icons in Auto-Naming"
description: "Updated auto-naming prompt to prefer outline SF Symbol variants over .fill versions."
created_at: 2026-03-01
tags: ["agent", "ui"]
icon: square.dashed
build: 76
---


# Prefer Outline Icons in Auto-Naming {square.dashed}
Updated the auto-naming prompt in AutocompleteService to prefer outline SF Symbol variants over `.fill` versions unless only a solid variant exists.

**Changed**: `Cloude/Cloude Agent/Services/AutocompleteService.swift`
