---
title: "Breadcrumb - Middle Truncation for Filenames"
description: "Breadcrumb filenames now use middle truncation to preserve file extensions."
created_at: 2026-02-08
tags: ["ui", "file-preview"]
icon: ellipsis.rectangle
build: 58
---


# Breadcrumb - Middle Truncation for Filenames
Filename in breadcrumb now uses middle truncation to preserve the file extension. e.g. `AutocompleteS….swift` instead of `AutocompleteS…`.

**File**: `Cloude/Cloude/UI/FileViewerBreadcrumb.swift`

**How to test**: Open a file with a long name — the breadcrumb filename should show the start + `…` + `.extension`.
