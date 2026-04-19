---
title: "JSON Tree Viewer"
description: "Added collapsible tree view for JSON files with color-coded values and source toggle."
created_at: 2026-02-07
tags: ["file-preview"]
icon: tree
build: 43
---


# JSON Tree Viewer
File viewer now defaults to a collapsible tree view for `.json` files. Objects and arrays are expandable with chevron toggles, collapsed nodes show item count (e.g. `{ 5 items }`). Values are color-coded: strings green, numbers orange, bools blue, null gray. Keys are sorted alphabetically. Same toolbar toggle as markdown to switch between tree view and syntax-highlighted source. Falls through to source view if JSON is malformed.
