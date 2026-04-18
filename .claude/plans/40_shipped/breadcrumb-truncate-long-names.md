---
title: "Breadcrumb: Truncate Long Path Components"
description: "Truncated each breadcrumb path component at 20 characters to prevent overflow."
created_at: 2026-02-08
tags: ["ui", "file-preview"]
icon: scissors
build: 55
---


# Breadcrumb: Truncate Long Path Components {scissors}
**Problem**: File viewer breadcrumb overflows when a directory or filename is very long.

**Fix**: Each path component truncates at 20 characters with `…` suffix. Applies to both directory segments and the final filename.

**File**: `Cloude/Cloude/UI/FileViewerBreadcrumb.swift`
