# Round: Environment Switch And Window Edit Sync

## Plan
- Scope: verify only two iOS behaviors.
- Behavior 1: before the first send, switching from `ENV_A` to `ENV_B` after choosing a folder under `ENV_A` must clear the previous working directory and fall back to `Select folder`.
- Behavior 2: while the window edit sheet stays open, refresh must target the currently linked conversation and live name or symbol updates must resync into the sheet controls.
- Scenario 1: pre-session environment switch and folder reset.
- Scenario 2: window edit sheet live-state sync.
- Target assertions:
- The folder row visibly resets from a concrete path to `Select folder` on environment change before first send.
- No stale file-search or other path-based request uses the old directory after switching environments.
- Refresh uses the currently linked conversation session and working directory.
- The open sheet updates its local name and symbol controls after an in-band conversation rename or symbol change.

## Baseline
- Pending launcher readiness.

## After
- Pending tester reports.

## Verdict
- Pending reviewer verdict.
- Launcher ready:
- sim=37E655E2-51C4-420B-B8B9-AB9EB6243FBE app=soli.Cloude log=/Users/soli/Library/Developer/CoreSimulator/Devices/37E655E2-51C4-420B-B8B9-AB9EB6243FBE/data/Containers/Data/Application/62F019EE-E590-478F-A4CA-D8B3B8273AC7/Documents/app-debug.log build=eb164edda9836db0a5b4196e9316855a95379870
- sim=C597F6B1-3F2A-4F54-B951-6729F5D5378B app=soli.Cloude log=/Users/soli/Library/Developer/CoreSimulator/Devices/C597F6B1-3F2A-4F54-B951-6729F5D5378B/data/Containers/Data/Application/5743B6B6-02DE-4623-813E-5D5735995DD9/Documents/app-debug.log build=eb164edda9836db0a5b4196e9316855a95379870
