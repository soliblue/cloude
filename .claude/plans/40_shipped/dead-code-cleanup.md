---
title: "Dead Code and Unused Imports Cleanup"
description: "Removed dead functions, unused scroll state vars, unused imports, and fixed force unwraps."
created_at: 2026-02-07
tags: ["refactor"]
icon: trash
build: 43
---


# Dead Code and Unused Imports Cleanup
**Status**: Active
**Agent**: Cleanup agent

## Tasks
1. Remove dead `extractCloudeCommands` function + `commandBuffer` state
2. Remove dead scroll state vars in ChatMessageList (`hasScrolledToStreaming`, `isPinnedToBottom`, `userIsDragging`)
3. Remove unused imports across codebase
4. Fix force unwraps in production code
