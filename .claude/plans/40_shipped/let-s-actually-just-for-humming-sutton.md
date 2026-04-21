# Clean stale subagents for v2

## Context

We just rewrote `deployer.md` + `fastlane/Fastfile` for v2 (scheme `Cloude Agent`, product `Remote CC Daemon.app`, builds to `/tmp/cloude-daemon-build`, v2 repo layout). User asked to audit the rest of `.claude/agents/` and clean anything else left over from v1.

v2 iOS is currently minimal: only **Endpoints + Settings + Theme + Debug** exist. Chat, streaming, files, git, sessions, workspace, whiteboard, memory, and deep-link navigation are not rebuilt yet. Deep-link schemes and UserDefaults-layer storage have changed (v2 uses `endpoints.json` in Application Support, not `environments.json` in Documents).

## Audit results

**Clean — no changes needed:**
- `analyst.md`
- `planner.md` (+ `planner/references/*.md`)
- `reviewer.md`
- `scribe.md`
- `solver.md`
- `launcher.md` (user already rewrote)
- `deployer.md` (fixed earlier this session)

**Stale — needs cleanup:** everything under `tester/` plus `tester.md`.

### Tester staleness

Every scenario, prompt, reference, and most scripts assume v1 features that don't exist in v2 yet.

| File | Line(s) | Issue |
|---|---|---|
| `tester.md` | 39, 47 | Polls `finish name=chat.complete`, lists baseline metrics `chat.firstToken`, `chat.complete`, `environment.auth`, `owcPerSec` — none exist in v2 |
| `scripts/run-perf-scenario.sh` | 66 | References `dismiss-sim-alerts.sh` which was deleted (v2 already removed it — visible in git status as ` D`) |
| `scripts/run-perf-scenario.sh` | 68–76 | Reads `Documents/environments.json`; v2 stores endpoints as `Application Support/endpoints.json` |
| `scripts/run-perf-scenario.sh` | 78–82 | Uses `cloude://conversation/environment`, `cloude://conversation/model` — routes don't exist in v2 |
| `scripts/open-simulator-url.sh` | 24–28 | Uses `type=` while `routes.md` documents `tab=` — pre-existing mismatch |
| `scenarios/abort-stop-run.md` | all | Tests chat abort — no chat in v2 |
| `scenarios/deep-link-navigation.md` | all | Tests `cloude://file`, `cloude://git`, `cloude://git/diff` — no files/git surfaces in v2; also references v1 path `clients/ios/Cloude/Features/Workspace/…` |
| `scenarios/long-markdown.md` | all | Tests markdown rendering during chat stream |
| `scenarios/streaming-lifecycle-stress.md` | all | Tests streaming/reconnect/relaunch in chat |
| `prompts/*.txt` | all | Chat prompts — assume chat exists |
| `references/routes.md` | 5–11 | ~25 v1 routes (chat, conversation, window, tab, memory, plans, whiteboard, usage, search, files, git, run, environment); v2 exposes ~none yet |
| `references/accessibility-ids.md` | unread but assumed | v1 widget IDs |
| `references/visual-capture.md` | unread but likely | Screenshot recipes tied to v1 surfaces |

Feature-agnostic scripts that are still useful: `capture-simulator-screenshot.sh`, `stream-simulator-logs.sh`, `summarize-render-logs.sh`, `send-simulator-message.sh`, `open-simulator-url.sh` (after `type=`→`tab=` fix).

## Plan

### 1. Archive v1 tester assets

Create `.claude/agents/tester/archive/` and move feature-dependent content there so it's preserved as reference for when features are rebuilt, without cluttering the active surface.

Move under `archive/`:
- `scenarios/` (all 4 files)
- `prompts/` (all 4 files)
- `references/routes.md`, `references/accessibility-ids.md` (leave `visual-capture.md` in place if it's feature-agnostic — verify during execution)
- `scripts/run-perf-scenario.sh`, `scripts/run-perf-regression.sh`, `scripts/run-scenarios-parallel.sh`, `scripts/open-repo-conversation.sh` (all tied to chat / v1 env storage / v1 deep links)

Keep in place:
- `scripts/capture-simulator-screenshot.sh`
- `scripts/stream-simulator-logs.sh`
- `scripts/summarize-render-logs.sh`
- `scripts/send-simulator-message.sh`
- `scripts/open-simulator-url.sh` (will be edited — see step 3)

### 2. Rewrite `.claude/agents/tester.md` for v2

New contents reflect current reality:
- Testable surface today: Endpoints CRUD, Settings (theme, font size, debug overlay), daemon `/ping` reachability from the sim.
- No chat metrics. Report whatever log signal the feature under test emits; no preset baseline metric list.
- Parallel dispatch and multi-sim language stays (still valid), but drop the `chat.complete` polling wording.
- Point at `archive/` for v1 scenarios and note they'll return as features ship.
- Keep the report schema, budget, and hard rules — those are framework, not feature-specific.

### 3. Fix `scripts/open-simulator-url.sh`

Change `type=` → `tab=` in lines 24–28 so it matches `routes.md` (even though the active routes are about to be archived, the param name should be consistent for when they return — and `open-simulator-url.sh` stays active).

Alternative: if user prefers, archive `open-simulator-url.sh` too, since v2 has essentially no deep-link surface yet. Flagged as an open decision below.

### 4. Reapply the `.claude/` edit workaround

CLAUDE.md notes that `.claude/` edits require the `cp` to `/tmp` → edit → `cp` back workaround, or `cat` heredoc. Use that for all the moves and rewrites in steps 1–3.

## Critical files

- `.claude/agents/tester.md` — rewrite
- `.claude/agents/tester/scenarios/*` — archive
- `.claude/agents/tester/prompts/*` — archive
- `.claude/agents/tester/references/routes.md`, `accessibility-ids.md` — archive
- `.claude/agents/tester/scripts/run-perf-scenario.sh`, `run-perf-regression.sh`, `run-scenarios-parallel.sh`, `open-repo-conversation.sh` — archive
- `.claude/agents/tester/scripts/open-simulator-url.sh` — edit (`type=` → `tab=`) or archive

## Verification

- `ls .claude/agents/tester/` shows only feature-agnostic scripts + `archive/` + `output/` + an empty `scenarios/`/`prompts/`/`references/` (or delete those dirs — TBD).
- `ls .claude/agents/tester/archive/` contains the moved files, fully recoverable.
- `grep -r chat.complete .claude/agents/tester.md` returns nothing.
- `grep -rn 'type=' .claude/agents/tester/scripts/open-simulator-url.sh` returns nothing (if we keep the script).
- Attempting to spawn the tester agent with a v2 task (e.g. "verify endpoint ping after add") works without hitting references to nonexistent files or deleted scripts.

## Open decisions

- Keep `open-simulator-url.sh` (fix `type=`) or archive it since v2 has no deep-link surface yet?
- Archive `references/visual-capture.md` or leave it? Need to read contents first.
- Delete the now-empty `scenarios/`, `prompts/`, `references/` dirs after moving, or keep them as placeholders?
