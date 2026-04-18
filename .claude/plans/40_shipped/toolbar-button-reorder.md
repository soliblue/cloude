---
title: "Toolbar Button Reorder"
description: "Swapped Settings and Plans button positions in the main toolbar."
created_at: 2026-02-08
tags: ["ui", "header"]
icon: arrow.left.arrow.right
build: 60
---


# Toolbar Button Reorder {arrow.left.arrow.right}
**Before**: Plans | Memories | Settings ... [Logo] ... Power
**After**: Settings | Memories | Plans ... [Logo] ... Power

Logo uses `.principal` placement which centers it in the navigation bar between the leading and trailing toolbar items.

## Changes
- `CloudeApp.swift` — Reordered toolbar buttons in `.topBarLeading` group
