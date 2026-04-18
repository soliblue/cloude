# Dead Code and Unused Imports Cleanup {trash}
<!-- priority: 10 -->
<!-- tags: refactor -->
<!-- build: 56 -->

> Removed dead functions, unused scroll state vars, unused imports, and fixed force unwraps.

**Status**: Active
**Agent**: Cleanup agent

## Tasks
1. Remove dead `extractCloudeCommands` function + `commandBuffer` state
2. Remove dead scroll state vars in ChatMessageList (`hasScrolledToStreaming`, `isPinnedToBottom`, `userIsDragging`)
3. Remove unused imports across codebase
4. Fix force unwraps in production code
