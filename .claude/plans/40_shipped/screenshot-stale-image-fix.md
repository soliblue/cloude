---
title: "Screenshot Stale Image Fix"
description: "Fixed race condition where screenshot attachment grabbed a stale photo by filtering by creation date and retrying."
created_at: 2026-03-14
tags: ["ui"]
icon: camera.badge.clock
build: 86
---


# Screenshot Stale Image Fix {camera.badge.clock}
Race condition where screenshot attachment could grab a stale photo from the library instead of the actual screenshot.

## Problem
`userDidTakeScreenshotNotification` fires before iOS writes the screenshot to the photo library. The 0.5s delay before fetching wasn't always enough, causing `loadLatestPhoto()` to grab the previous latest image.

## Fix
- Filter photos to those created in the last 3 seconds (`creationDate > cutoff`)
- Retry up to 5 times (every 0.3s) if no recent photo is found
- Give up silently instead of attaching a stale image

**Files:** `MainChatView+Utilities.swift`
