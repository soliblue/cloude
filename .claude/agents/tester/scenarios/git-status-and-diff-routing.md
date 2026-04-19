# Git Status And Diff Routing

Verify that git status and git diff requests use the conversation environment that owns the window.

Resolve the test fixture once:

```bash
UDID="${SIMULATOR_UDID:-booted}"
APP_CONTAINER="$(xcrun simctl get_app_container "$UDID" soli.Cloude data)"
LOG_PATH="$APP_CONTAINER/Documents/app-debug.log"
ENV_FILE="$APP_CONTAINER/Documents/environments.json"
REPO="$(git rev-parse --show-toplevel)"
START_LINE="$(wc -l < "$LOG_PATH" 2>/dev/null || echo 1)"

eval "$(ENV_FILE="$ENV_FILE" python3 - <<'PY'
import json, os
path = os.environ['ENV_FILE']
with open(path) as f:
    envs = json.load(f)
base = dict(envs[0])
other = dict(base)
other['id'] = 'c10de51d-5151-4551-8551-0000000b0b0b'
other['symbol'] = 'laptopcomputer'
with open(path, 'w') as f:
    json.dump([base, other], f, indent=2)
print(f"ENV_A={base['id']}")
print(f"ENV_B={other['id']}")
PY
)"

xcrun simctl terminate "$UDID" soli.Cloude || true
xcrun simctl launch "$UDID" soli.Cloude
sleep 2
xcrun simctl openurl "$UDID" "cloude://environment/connect?id=${ENV_A}"
xcrun simctl openurl "$UDID" "cloude://environment/connect?id=${ENV_B}"
sleep 2
SIMULATOR_UDID="$UDID" /Users/soli/Desktop/CODING/cloude/.claude/agents/tester/scripts/open-repo-conversation.sh "$REPO"
```

1. Switch the conversation to `ENV_A`.
2. Open the git surface for `REPO`:

```bash
xcrun simctl openurl "$UDID" "cloude://git?path=${REPO}"
```

3. Open the diff surface for `Cloude/Cloude/Features/Workspace/Utils/WorkspaceActions.swift`:

```bash
xcrun simctl openurl "$UDID" "cloude://git/diff?path=${REPO}&file=Cloude/Cloude/Features/Workspace/Utils/WorkspaceActions.swift&staged=false"
```

4. Close the diff view if needed.
5. Switch the conversation to `ENV_B`.
6. Repeat the git surface and diff flow.
7. Inspect the fresh log slice:

```bash
sed -n "${START_LINE},\$p" "$LOG_PATH" | grep -E "git status request envId=|git diff request envId=|git status response envId=|git diff response envId="
```

## Assertions

- the first git status and git diff requests are logged with `ENV_A`
- the repeated git status and git diff requests are logged with `ENV_B`
- no git request is routed through the wrong environment id after switching
- the diff view always opens the requested file and does not reuse stale content
