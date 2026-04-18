---
title: "CSV Header Padding Fix"
description: "Removed extra vertical padding between breadcrumb header and CSV table content in file preview."
created_at: 2026-02-08
tags: ["ui", "file-preview"]
icon: rectangle.arrowtriangle.2.inward
build: 63
---


# CSV Header Padding Fix {rectangle.arrowtriangle.2.inward}
## What
Remove extra vertical padding between the breadcrumb header and CSV table content in the file preview.

## Changes
- `FilePathPreviewView+Content.swift`: Removed `.padding(.vertical)` from CSV rendered view
