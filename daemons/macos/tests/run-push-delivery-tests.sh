#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-push-delivery.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/Provisioning/RemoteTunnelIdentity.swift" \
  "$ROOT/src/Notifications/PushEntry.swift" \
  "$ROOT/src/Notifications/PushDelivery.swift" \
  "$ROOT/tests/PushDeliveryTests.swift" \
  -o "$TEMP/push-delivery-tests"
"$TEMP/push-delivery-tests"
