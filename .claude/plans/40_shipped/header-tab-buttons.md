---
title: "Header Tab Buttons"
description: "Replaced window header title pill with Chat/Files/Git tab icon buttons."
created_at: 2026-03-08
tags: ["ui", "header"]
icon: rectangle.3.group
build: 82
---


# Header Tab Buttons {rectangle.3.group}
## Changes
- CloudeApp.swift: Added `.principal` toolbar item with conversation name/folder/cost (no SF symbol)
- MainChatView+Windows.swift: Replaced title pill with 3 tab icon buttons (WindowType.allCases)
- MainChatView.swift: Added `.editActiveWindow` notification listener
- WidgetView+Shared.swift: Added `.editActiveWindow` notification name

## Status
Implemented, awaiting deploy and testing.
