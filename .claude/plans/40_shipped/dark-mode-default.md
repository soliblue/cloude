---
title: "Dark Mode Default"
description: "Defaulted app theme to dark mode instead of following system setting."
created_at: 2026-02-08
tags: ["ui", "theme"]
icon: moon.fill
build: 67
---


# Dark Mode Default {moon.fill}
Default the app theme to dark mode instead of system. Users can still override to system or light in Settings.

## Changes
- `CloudeApp.swift`: Changed `@AppStorage("appTheme")` default from `.system` to `.dark`
