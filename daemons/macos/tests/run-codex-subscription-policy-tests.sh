#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-codex-policy.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/CodexSubscriptionPolicy.swift" "$ROOT/tests/CodexSubscriptionPolicyTests.swift" -o "$TEMP/policy-tests"
"$TEMP/policy-tests"
