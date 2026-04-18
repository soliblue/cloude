---
title: "WindowSwitcher Tab Icon and Text Size Bump"
description: "Increases bottom WindowTabBar symbol icon from DS.Icon.m to DS.Icon.l and conversation name text from DS.Text.m to DS.Text.l; adds DS.Text.l token to Theme.swift."
created_at: 2026-04-18
tags: ["ui"]
icon: rectangle.3.group
---

# WindowSwitcher Tab Icon and Text Size Bump {rectangle.3.group}

Bottom window switcher tab bar items were rendering at 17pt icon / 13.5pt text. Bumped to DS.Icon.l (19pt) and DS.Text.l (16pt) for better legibility. Added the missing DS.Text.l token to the Text enum in Theme.swift alongside existing `.s` and `.m`.
