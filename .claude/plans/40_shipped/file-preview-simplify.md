---
title: "Simplify File Preview Navigation"
description: "Remove folder-browsing capability from FilePreviewView, making it a read-only file viewer without embedded navigation."
created_at: 2026-04-18
tags: ["files", "ui"]
icon: doc.text
---

# Simplify File Preview Navigation {doc.text}

Removed the `onBrowseFolder` callback, `browsingFolder` state, and embedded `FileBrowserView` from `FilePreviewView`. Breadcrumb components no longer render tappable folder links. The file preview is now a pure read-only viewer.

Followed up by extracting `FilePreviewMarkdownView` to replace the direct `StreamingMarkdownView` call in `FilePreviewView+Content`. Markdown content now renders through the block-based `StreamingMarkdownParser` and `StreamingBlockView` pipeline, matching the rendering quality of the chat view.
