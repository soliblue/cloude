#!/bin/bash
set -euo pipefail

DEVICE_NAME_ARG=""
SKIP_DAEMON=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      DEVICE_NAME_ARG="$2"
      shift 2
      ;;
    --skip-daemon)
      SKIP_DAEMON=1
      shift
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUNDLE_ID="soli.Cloude"
HOST="127.0.0.1"
PORT="8765"
ENV_ID="c10de51d-5151-4551-8551-0000000c10de"
KEYCHAIN_SERVICE="soli.Cloude.agent"
KEYCHAIN_ACCOUNT="authToken"
DAEMON_APP_NAME="Remote CC Daemon"
DAEMON_BUILD_DIR="/tmp/cloude-daemon-build"
IOS_BUILD_DIR="/tmp/cloude-ios-build"
DAEMON_APP_PATH="$DAEMON_BUILD_DIR/Build/Products/Debug/$DAEMON_APP_NAME.app"
IOS_APP_PATH="$IOS_BUILD_DIR/Build/Products/Debug-iphonesimulator/Cloude.app"

fail() {
  echo "failed: $1, $2" >&2
  exit 1
}

DEVICE_ID=""
DEVICE_DISPLAY=""
RESOLVED="$(DEVICE_NAME="$DEVICE_NAME_ARG" python3 <<'PYEOF'
import json, os, subprocess
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
data = json.loads(raw)
name_filter = os.environ.get("DEVICE_NAME", "").strip()

def ios_version(rid):
    if "iOS-" not in rid: return None
    try: return tuple(int(x) for x in rid.split("iOS-", 1)[1].split("-"))
    except ValueError: return None

candidates = []
for rid, devices in data["devices"].items():
    v = ios_version(rid)
    if v is None: continue
    for d in devices:
        if "iPhone" not in d["name"]: continue
        if name_filter and name_filter not in d["name"]: continue
        candidates.append((v, d.get("state") == "Booted", d["udid"], d["name"]))
candidates.sort(key=lambda c: (tuple(-x for x in c[0]), not c[1], c[3]))
if candidates:
    print(f"{candidates[0][2]}\t{candidates[0][3]}")
PYEOF
)"
if [[ -z "$RESOLVED" ]]; then fail "resolve" "no iPhone simulator available"; fi
IFS=$'\t' read -r DEVICE_ID DEVICE_DISPLAY <<< "$RESOLVED"
echo "sim: $DEVICE_DISPLAY ($DEVICE_ID)"

if [[ "$SKIP_DAEMON" -eq 0 ]]; then
  echo "build_daemon..."
  xcodebuild -project "$REPO_ROOT/daemons/macos/macOSDaemon.xcodeproj" \
    -scheme "Cloude Agent" -configuration Debug \
    -derivedDataPath "$DAEMON_BUILD_DIR" build >/dev/null \
    || fail "build_daemon" "xcodebuild failed"
  [[ -d "$DAEMON_APP_PATH" ]] || fail "build_daemon" "app not at $DAEMON_APP_PATH"

  pkill -9 -f "$DAEMON_APP_NAME" 2>/dev/null || true
  sleep 1
  open "$DAEMON_APP_PATH" || fail "launch_daemon" "open failed"
fi

TOKEN=""
for _ in {1..15}; do
  TOKEN="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null || true)"
  [[ -n "$TOKEN" ]] && break
  sleep 1
done
[[ -n "$TOKEN" ]] || fail "token" "no token in Keychain after 15s"

DAEMON_PID="$(pgrep -f "$DAEMON_APP_NAME" | head -1)"
[[ -n "$DAEMON_PID" ]] || fail "launch_daemon" "daemon not running"

PING="$(curl -sS -m 3 -H "Authorization: Bearer $TOKEN" "http://$HOST:$PORT/ping" 2>&1 || true)"
echo "$PING" | grep -q '"ok":true' || fail "daemon_probe" "ping did not return ok: $PING"

if ! xcrun simctl list devices booted | grep -q "$DEVICE_ID"; then
  echo "boot..."
  xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || fail "boot" "simctl boot failed"
fi
open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null 2>&1 || fail "boot" "bootstatus failed"

echo "build_ios..."
xcodebuild -project "$REPO_ROOT/clients/ios/iOS.xcodeproj" \
  -scheme Cloude -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$IOS_BUILD_DIR" build >/dev/null \
  || fail "build_ios" "xcodebuild failed"
[[ -d "$IOS_APP_PATH" ]] || fail "build_ios" "app not at $IOS_APP_PATH"

echo "install..."
xcrun simctl install "$DEVICE_ID" "$IOS_APP_PATH" || fail "install" "simctl install failed"

echo "launch..."
SIMCTL_CHILD_CLOUDE_DEV_TOKEN="$TOKEN" \
SIMCTL_CHILD_CLOUDE_DEV_HOST="$HOST" \
SIMCTL_CHILD_CLOUDE_DEV_PORT="$PORT" \
SIMCTL_CHILD_CLOUDE_DEV_ENV_ID="$ENV_ID" \
  xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" >/dev/null \
  || fail "launch" "simctl launch failed"

echo "ready: sim=$DEVICE_ID bundle=$BUNDLE_ID daemon_pid=$DAEMON_PID token=$TOKEN host=$HOST port=$PORT env_id=$ENV_ID"
