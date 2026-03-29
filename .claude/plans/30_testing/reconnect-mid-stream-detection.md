# Reconnect Mid-Stream Detection {arrow.triangle.2.circlepath}
<!-- priority: 9 -->
<!-- tags: streaming, agent -->
<!-- build: 120 -->

> When closing the app mid-stream and reconnecting, the agent now resumes the streaming indicator automatically instead of requiring manual refreshes.

## Problem
If the app is closed or the connection drops while Claude is actively streaming a response, reconnecting shows the partial content as a completed message. The user had to manually tap "refresh" repeatedly to get more content as Claude continued generating.

## Root Cause
On reconnect, the iOS app sends `requestMissedResponse(sessionId:)`. The Mac agent only checked `ResponseStore` (completed responses). If Claude was still running, it sent `noMissedResponse`, which caused the client to mark the output as done. Meanwhile Claude kept generating on the Mac — the next `refresh` would fetch more history.

## Fix
In `AppDelegate+MessageHandling.swift`, when `requestMissedResponse` arrives and no stored completed response exists, the agent now checks `runnerManager.activeRunners` for a matching session. If found and still running, it sends `status(.running, conversationId:)` to the reconnected client. The runner's output callbacks already broadcast to all authenticated connections, so future chunks arrive automatically.

## How to Test
1. Start a long Claude response (ask for a detailed multi-section explanation)
2. While it's streaming, close the app completely
3. Reopen the app immediately
4. The streaming indicator should appear automatically without any manual refresh
5. The response should continue streaming to completion
