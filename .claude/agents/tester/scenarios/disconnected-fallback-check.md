# Disconnected Fallback Check

Verify that disconnecting one environment does not leak disconnected state into windows bound to another environment.

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

1. Switch the conversation to `ENV_B`.
2. Open the files or git surface and confirm it is loaded.
3. Disconnect `ENV_A`:

```bash
xcrun simctl openurl "$UDID" "cloude://environment/disconnect?id=${ENV_A}"
```

4. Confirm the active conversation bound to `ENV_B` still works and does not flip to a disconnected state.
5. Disconnect `ENV_B`.
6. Confirm the active conversation now shows the expected disconnected behavior.
7. Inspect the fresh log slice:

```bash
sed -n "${START_LINE},\$p" "$LOG_PATH" | grep -E "disconnect envId=|directory request envId=|git status request envId="
```

## Assertions

- disconnecting `ENV_A` does not break a conversation bound to `ENV_B`
- the active window only becomes disconnected after `ENV_B` is disconnected
- no file or git request after step 3 is rerouted onto `ENV_A`
- the UI does not keep stale connected state after `ENV_B` disconnects
