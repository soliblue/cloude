# Folder Browse And Preview

Verify that folder browsing and file preview stay on the active conversation environment.

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
2. Open the files surface for the repo root:

```bash
xcrun simctl openurl "$UDID" "cloude://files?path=${REPO}"
```

3. Wait for the file tree to load, then open a visible source file in the file browser.
4. Close the file preview.
5. Switch the conversation to `ENV_B`.
6. Repeat the same browse and preview flow.
7. Inspect the fresh log slice:

```bash
sed -n "${START_LINE},\$p" "$LOG_PATH" | grep -E "directory request envId=|file request envId="
```

## Assertions

- the first directory listing and preview request are logged with `ENV_A`
- the repeated browse and preview flow is logged with `ENV_B`
- no directory request for the repeated flow lands on the previous environment id
- the file browser and preview keep matching the selected conversation environment
