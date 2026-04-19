#!/bin/bash
set -euo pipefail

COUNT=1
DEVICE_NAME_ARG=""
SKIP_AGENT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count)
      COUNT="$2"
      shift 2
      ;;
    --skip-agent)
      SKIP_AGENT=1
      shift
      ;;
    *)
      DEVICE_NAME_ARG="$1"
      shift
      ;;
  esac
done

if [[ "$COUNT" -lt 1 || "$COUNT" -gt 3 ]]; then
  echo "Invalid --count: $COUNT (must be 1-3)" >&2
  exit 1
fi

DEVICE_NAME="${DEVICE_NAME_ARG:-${CLOUDE_SIM_DEVICE_NAME:-}}"
HOST="${CLOUDE_SIM_HOST:-127.0.0.1}"
PORT="${CLOUDE_SIM_PORT:-8765}"
BUNDLE_ID="${CLOUDE_BUNDLE_ID:-soli.Cloude}"
DERIVED_DATA_PATH="${CLOUDE_SIM_DERIVED_DATA:-/tmp/cloude-sim-build}"
SYMBOL="${CLOUDE_SIM_SYMBOL:-desktopcomputer}"

DEVICE_IDS=()
DEVICE_DISPLAY_NAMES=()

RESOLVED="$(COUNT="$COUNT" DEVICE_NAME="$DEVICE_NAME" python3 <<'PYEOF'
import json, os, subprocess

raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
data = json.loads(raw)
count = int(os.environ.get("COUNT", "1"))
name_filter = os.environ.get("DEVICE_NAME", "").strip()

def ios_version(runtime_id):
    if "iOS-" not in runtime_id:
        return None
    tail = runtime_id.split("iOS-", 1)[1]
    parts = tail.split("-")
    try:
        return tuple(int(x) for x in parts)
    except ValueError:
        return None

candidates = []
for runtime_id, devices in data["devices"].items():
    version = ios_version(runtime_id)
    if version is None:
        continue
    for device in devices:
        if "iPhone" not in device["name"]:
            continue
        if name_filter and name_filter not in device["name"]:
            continue
        booted = device.get("state") == "Booted"
        candidates.append((version, booted, device["udid"], device["name"]))

candidates.sort(key=lambda c: (tuple(-v for v in c[0]), not c[1], c[3]))

for version, booted, udid, device_name in candidates[:count]:
    print(f"{udid}\t{device_name}")
PYEOF
)"

while IFS=$'\t' read -r udid name; do
  [[ -z "$udid" ]] && continue
  DEVICE_IDS+=("$udid")
  DEVICE_DISPLAY_NAMES+=("$name")
done <<< "$RESOLVED"

if [[ ${#DEVICE_IDS[@]} -lt $COUNT ]]; then
  echo "Only resolved ${#DEVICE_IDS[@]} iPhone simulator(s); $COUNT requested. Check iOS runtime availability." >&2
  exit 1
fi

echo "Resolved ${#DEVICE_IDS[@]} simulator(s):"
for i in "${!DEVICE_IDS[@]}"; do
  echo "  ${DEVICE_DISPLAY_NAMES[$i]} (${DEVICE_IDS[$i]})"
done

if [[ "$SKIP_AGENT" -eq 0 ]]; then
  echo "Building and launching Mac agent..."
  set -a
  source .env
  set +a
  fastlane mac build_agent
else
  echo "Skipping Mac agent build (--skip-agent); using existing agent + token"
fi

TOKEN=""
for _ in {1..10}; do
    TOKEN="$(security find-generic-password -s com.cloude.agent -a authToken -w 2>/dev/null || true)"
    if [[ -n "$TOKEN" ]]; then
        break
    fi
    sleep 1
done

if [[ -z "$TOKEN" ]]; then
    echo "No auth token found in Keychain (agent never ran?)"
    exit 1
fi

for i in "${!DEVICE_IDS[@]}"; do
  DEVICE_ID="${DEVICE_IDS[$i]}"
  DEVICE_DISPLAY="${DEVICE_DISPLAY_NAMES[$i]}"
  if xcrun simctl list devices booted | grep -q "$DEVICE_ID"; then
    echo "Using already booted simulator $DEVICE_DISPLAY ($DEVICE_ID)"
  else
    echo "Booting simulator $DEVICE_DISPLAY ($DEVICE_ID)..."
    xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
  fi
done

if [[ ${#DEVICE_IDS[@]} -eq 1 ]]; then
  open -a Simulator --args -CurrentDeviceUDID "${DEVICE_IDS[0]}" >/dev/null 2>&1 || true
else
  open -a Simulator >/dev/null 2>&1 || true
fi

for DEVICE_ID in "${DEVICE_IDS[@]}"; do
  xcrun simctl bootstatus "$DEVICE_ID" -b
done

echo "Building iOS app..."
env GIT_CONFIG_GLOBAL=/dev/null xcodebuild -project Cloude/Cloude.xcodeproj \
    -scheme Cloude \
    -destination "platform=iOS Simulator,id=${DEVICE_IDS[0]}" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Cloude.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "Built Cloude.app not found at $APP_PATH"
    exit 1
fi

ENV_ID="${CLOUDE_SIM_ENV_ID:-c10de51d-5151-4551-8551-0000000c10de}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for i in "${!DEVICE_IDS[@]}"; do
  DEVICE_ID="${DEVICE_IDS[$i]}"
  DEVICE_DISPLAY="${DEVICE_DISPLAY_NAMES[$i]}"

  echo ""
  echo "Installing app into $DEVICE_DISPLAY ($DEVICE_ID)..."
  xcrun simctl install "$DEVICE_ID" "$APP_PATH"

  sleep 1

  echo "Seeding environment for $DEVICE_ID..."
  CONTAINER_PATH="$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data)"
  DOCUMENTS_PATH="$CONTAINER_PATH/Documents"
  PREFERENCES_DOMAIN="$CONTAINER_PATH/Library/Preferences/$BUNDLE_ID"

  mkdir -p "$DOCUMENTS_PATH"
  cat > "$DOCUMENTS_PATH/environments.json" <<ENV_EOF
[
  {
    "id": "$ENV_ID",
    "host": "$HOST",
    "port": $PORT,
    "token": "$TOKEN",
    "symbol": "$SYMBOL"
  }
]
ENV_EOF

  defaults write "$PREFERENCES_DOMAIN" activeEnvironmentId -string "$ENV_ID"
  xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" debugOverlayEnabled -bool true

  echo "Launching app on $DEVICE_ID..."
  SIMCTL_CHILD_CLOUDE_SKIP_PROMPTS=1 \
    xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" >/dev/null

  sleep 2
  echo "Warmup deep-link on $DEVICE_ID (consent prompt tax)..."
  xcrun simctl openurl "$DEVICE_ID" "cloude://environment/select?id=$ENV_ID" >/dev/null
  sleep 2
  echo "Dismissing any consent prompts..."
  "$SCRIPT_DIR/dismiss-sim-alerts.sh" 10 >/dev/null 2>&1 || true
done

echo ""
echo "Waiting for auth-ready on each sim..."
AUTH_TIMEOUT=30
for i in "${!DEVICE_IDS[@]}"; do
  DEVICE_ID="${DEVICE_IDS[$i]}"
  DEVICE_DISPLAY="${DEVICE_DISPLAY_NAMES[$i]}"
  CONTAINER_PATH="$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data)"
  LOG_PATH="$CONTAINER_PATH/Documents/app-debug.log"
  WAIT_START=$(date +%s)
  while true; do
    if grep -q "finish name=environment.auth .* success=true" "$LOG_PATH" 2>/dev/null; then
      echo "  $DEVICE_DISPLAY: auth success after $(( $(date +%s) - WAIT_START ))s"
      break
    fi
    if (( $(date +%s) - WAIT_START >= AUTH_TIMEOUT )); then
      echo "  $DEVICE_DISPLAY: TIMEOUT waiting for auth success after ${AUTH_TIMEOUT}s" >&2
      exit 1
    fi
    sleep 1
  done
done

echo ""
echo "Ready:"
for i in "${!DEVICE_IDS[@]}"; do
  DEVICE_ID="${DEVICE_IDS[$i]}"
  DEVICE_DISPLAY="${DEVICE_DISPLAY_NAMES[$i]}"
  CONTAINER_PATH="$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data)"
  LOG_PATH="$CONTAINER_PATH/Documents/app-debug.log"
  echo "  udid=$DEVICE_ID name=\"$DEVICE_DISPLAY\" bundle=$BUNDLE_ID log=$LOG_PATH"
done
echo "Host: $HOST:$PORT"
