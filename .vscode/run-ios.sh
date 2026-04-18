#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Cloude/Cloude.xcodeproj"
SCHEME_NAME="${CLOUDE_SCHEME:-Cloude}"
SIMULATOR_DERIVED_DATA_PATH="$ROOT_DIR/build/vscode-simulator"
DEVICE_DERIVED_DATA_PATH="$ROOT_DIR/build/vscode-device"
BUNDLE_IDENTIFIER="soli.Cloude"
MODE="${1:-simulator}"
DEVICECTL_UUID_PATTERN='^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$'

simulator_id_from_args="${2:-}"
device_id_from_args="${2:-}"

resolve_simulator_id() {
  if [[ -n "${CLOUDE_SIMULATOR_ID:-}" ]]; then
    echo "$CLOUDE_SIMULATOR_ID"
    return
  fi

  if [[ -n "$simulator_id_from_args" ]]; then
    echo "$simulator_id_from_args"
    return
  fi

  local json_path
  json_path="$(mktemp)"
  xcrun simctl list devices available --json > "$json_path"
  local booted_id
  booted_id="$(/usr/bin/ruby -rjson -e 'data = JSON.parse(File.read(ARGV[0])); runtime = data.fetch("devices").keys.sort.reverse.find { |name| data.fetch("devices").fetch(name).any? { |item| item.fetch("isAvailable") && item.fetch("state") == "Booted" } }; device = runtime ? data.fetch("devices").fetch(runtime).find { |item| item.fetch("isAvailable") && item.fetch("state") == "Booted" } : nil; puts(device.fetch("udid")) if device' "$json_path")"

  if [[ -n "$booted_id" ]]; then
    rm -f "$json_path"
    echo "$booted_id"
    return
  fi

  /usr/bin/ruby -rjson -e 'data = JSON.parse(File.read(ARGV[0])); runtime = data.fetch("devices").keys.sort.reverse.find { |name| data.fetch("devices").fetch(name).any? { |item| item.fetch("isAvailable") && item.fetch("name").include?("iPhone") } }; device = runtime ? data.fetch("devices").fetch(runtime).find { |item| item.fetch("isAvailable") && item.fetch("name").include?("iPhone") } : nil; puts(device.fetch("udid")) if device' "$json_path"
  rm -f "$json_path"
}

resolve_xcode_device_id() {
  if [[ -n "${CLOUDE_XCODE_DEVICE_ID:-}" ]]; then
    echo "$CLOUDE_XCODE_DEVICE_ID"
    return
  fi

  if [[ -n "${CLOUDE_DEVICE_ID:-}" ]]; then
    if [[ ! "$CLOUDE_DEVICE_ID" =~ $DEVICECTL_UUID_PATTERN ]]; then
      echo "$CLOUDE_DEVICE_ID"
      return
    fi
  fi

  if [[ -n "$device_id_from_args" ]]; then
    if [[ ! "$device_id_from_args" =~ $DEVICECTL_UUID_PATTERN ]]; then
      echo "$device_id_from_args"
      return
    fi
  fi

  xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" -showdestinations 2>&1 \
    | grep "platform:iOS, arch:" \
    | head -1 \
    | sed -E 's/.*id:([^,}]+).*/\1/'
}

resolve_devicectl_device_id() {
  if [[ -n "${CLOUDE_DEVICECTL_ID:-}" ]]; then
    echo "$CLOUDE_DEVICECTL_ID"
    return
  fi

  if [[ -n "${CLOUDE_DEVICE_ID:-}" ]]; then
    if [[ "$CLOUDE_DEVICE_ID" =~ $DEVICECTL_UUID_PATTERN ]]; then
      echo "$CLOUDE_DEVICE_ID"
      return
    fi
  fi

  if [[ -n "$device_id_from_args" ]]; then
    if [[ "$device_id_from_args" =~ $DEVICECTL_UUID_PATTERN ]]; then
      echo "$device_id_from_args"
      return
    fi
  fi

  local json_path
  json_path="$(mktemp)"
  xcrun devicectl list devices --json-output "$json_path" >/dev/null
  /usr/bin/ruby -rjson -e 'data = JSON.parse(File.read(ARGV[0])); device = data.fetch("result").fetch("devices").find { |item| item.dig("hardwareProperties", "platform") == "iOS" && item.dig("connectionProperties", "pairingState") == "paired" && item.dig("deviceProperties", "developerModeStatus") == "enabled" }; puts(device.fetch("identifier")) if device' "$json_path"
  rm -f "$json_path"
}

run_on_simulator() {
  local simulator_id
  simulator_id="$(resolve_simulator_id)"

  if [[ -z "$simulator_id" ]]; then
    echo "No available simulator found."
    exit 1
  fi

  open -a Simulator
  xcrun simctl boot "$simulator_id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$simulator_id" -b
  xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" -configuration Debug -destination "id=$simulator_id" -derivedDataPath "$SIMULATOR_DERIVED_DATA_PATH" build
  xcrun simctl install "$simulator_id" "$SIMULATOR_DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Cloude.app"
  xcrun simctl launch --console --terminate-running-process "$simulator_id" "$BUNDLE_IDENTIFIER"
}

run_on_device() {
  local xcode_device_id
  xcode_device_id="$(resolve_xcode_device_id)"

  if [[ -z "$xcode_device_id" ]]; then
    echo "No connected iPhone was found in Xcode destinations."
    exit 1
  fi

  local devicectl_device_id
  devicectl_device_id="$(resolve_devicectl_device_id)"

  if [[ -z "$devicectl_device_id" ]]; then
    echo "No paired iPhone with Developer Mode enabled was found."
    exit 1
  fi

  xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" -configuration Debug -destination "id=$xcode_device_id" -derivedDataPath "$DEVICE_DERIVED_DATA_PATH" build
  xcrun devicectl device install app --device "$devicectl_device_id" "$DEVICE_DERIVED_DATA_PATH/Build/Products/Debug-iphoneos/Cloude.app"
  xcrun devicectl device process launch --console --terminate-existing --device "$devicectl_device_id" "$BUNDLE_IDENTIFIER"
}

if [[ "$MODE" == "simulator" ]]; then
  run_on_simulator
elif [[ "$MODE" == "device" ]]; then
  run_on_device
else
  echo "Usage: .vscode/run-ios.sh [simulator|device] [target-id]"
  exit 1
fi
