# FPS Drop on First Launch {gauge.medium}
<!-- build: 120 -->
<!-- priority: 8 -->
<!-- tags: ui, performance -->

> App stutters noticeably on first launch after being closed.

## Problem
When opening the app from a cold start, there is a visible drop in frame rate during the initial render. The app feels janky for a brief moment before stabilizing.

## Desired Outcome
The app opens smoothly with no perceptible stutter or FPS drop, consistent with how it feels after the first launch.

## What We Found
- Cold-launch FPS drop is reproducible across repeated terminate-and-relaunch cycles.
- Typical startup samples were around `fps=0`, then `fps=42-45`, then recovery to `fps=59-61`.
- `environment.auth` itself was usually fast and not the main bottleneck.
- A real bug was found in startup reconnect behavior: auth was being started twice on launch.
- Fixing duplicate reconnect removed the second `environment.auth` start, but did not eliminate the FPS drop.
- Deferring the eager git status sweep helped reduce one source of startup work, but did not eliminate the FPS drop.
- Deferring notification permission did not help.
- Launching into a blank lightweight conversation instead of a heavy restored transcript did not help.

## Changes Tried
- Prevented `reconnectIfNeeded()` from reconnecting while already connected.
- Deferred the eager `checkGitForAllDirectories()` startup task until after auth and several seconds after launch.
- Experimented with delaying notification permission, then reverted that experiment.
- Tested launch with a blank active conversation, then restored the previous simulator state.

## Current Read
The issue is still present. The most likely remaining causes are in first-render SwiftUI/layout work or in how the FPS metric is sampled during the very first second of launch. This needs deeper profiling or more targeted instrumentation rather than more blind startup deferrals.

## How to Test
1. Close the app completely (swipe up from app switcher)
2. Wait a few seconds
3. Reopen the app
4. Watch the initial render — it should feel instant and smooth with no jank
5. Repeat 3 times to confirm consistency
