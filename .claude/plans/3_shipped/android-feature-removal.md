---
title: "Android Feature Removal"
description: "Remove Memories, Plans, UsageStats, Deploy, and Terminal features from the Android app."
created_at: 2026-04-18
tags: ["android", "ui"]
build: 156
icon: trash
---

# Android Feature Removal

> Remove non-functional or retired Android features to reduce dead code.

## What was removed
- `MemoriesSheet`, `MemoriesScreen`, `MemoryModels`, `MemoryParser` - memories view and backing models
- `PlansSheet`, `PlansScreen` - plans view
- `UsageStatsSheet` - usage stats modal
- `DeploySheet` - deploy panel and its RocketLaunch toolbar button
- `ClientMessage`: `GetMemories`, `GetPlans`, `DeletePlan`, `GetUsageStats`, `TerminalExec`, `TerminalInput`
- `ServerMessage`: `Memories`, `Plans`, `PlanDeleted`, `UsageStatsMsg`, `TerminalOutput`
- `SharedTypes`: `MemorySection`, `PlanItem`, `UsageStats`, `DailyActivity`, `ModelTokenUsage`, `LongestSession`
- `WindowType`: `Memories`, `Plans` variants
- `DeepLinkRouter`: `usage`, `memory`, `memories`, `plans`, `deploy` routes and `showDeploy` UIAction
- `SlashCommand`: `/usage` built-in and hint text
- `ChatViewModel`: `requestUsageStats`, `requestPlans`, `deletePlan`, `dismissUsageStats`, `dismissPlans`, `requestMemories` plus backing state flows
- `WindowManager`: defensive `valueOf` replaced with safe lookup to survive stale persisted window types

## Files deleted
- `MemoryModels.kt`, `MemoryParser.kt`, `PlansSheet.kt`, `UsageStatsSheet.kt`, `DeploySheet.kt`, `MemoriesSheet.kt`
