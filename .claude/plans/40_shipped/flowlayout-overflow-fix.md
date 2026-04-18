---
title: "FlowLayout Overflow Fix"
description: "Fixed FlowLayout measuring subviews without width constraint, causing text overflow."
created_at: 2026-03-04
tags: ["ui", "widget"]
icon: rectangle.compress.vertical
build: 82
---


# FlowLayout Overflow Fix {rectangle.compress.vertical}
## Problem
FlowLayout measured subviews with `.unspecified` (no width constraint), so long text segments in widgets like Error Correction overflowed the screen width.

## Solution
- Constrain subviews to remaining row width when measuring and placing
- Added `.fixedSize(horizontal: false, vertical: true)` to ErrorCorrection text segments
