# Multi Environment File Routing

Verify that file preview requests follow the conversation environment, not the global selection.

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
```

1. Open a repo conversation rooted at `REPO`:

```bash
SIMULATOR_UDID="$UDID" /Users/soli/Desktop/CODING/cloude/.claude/agents/tester/scripts/open-repo-conversation.sh "$REPO"
```

2. Switch the conversation to `ENV_A`:

```bash
xcrun simctl openurl "$UDID" "cloude://conversation/environment?id=${ENV_A}"
```

3. Open a file preview for `README.md`:

```bash
xcrun simctl openurl "$UDID" "cloude://file${REPO}/README.md"
```

4. Close the preview if needed.
5. Switch the conversation to `ENV_B`.
6. Open the same file preview again.
7. Inspect the fresh log slice:

```bash
sed -n "${START_LINE},\$p" "$LOG_PATH" | grep "file request envId="
```

## Assertions

- the first `README.md` request is logged with `ENV_A`
- the second `README.md` request is logged with `ENV_B`
- no request for `README.md` is logged against the wrong environment id
- the file preview opens both times without stale content from the previous environment
