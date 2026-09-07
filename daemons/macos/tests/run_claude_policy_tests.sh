#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-claude-policy.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/ClaudeSubscriptionPolicy.swift" "$ROOT/tests/ClaudeSubscriptionPolicyTests.swift" -o "$TEMP/policy-tests"
"$TEMP/policy-tests"
swiftc "$ROOT/src/ClaudeSubscriptionPolicy.swift" "$ROOT/src/Runner.swift" "$ROOT/tests/PushDeliveryReviewStub.swift" "$ROOT/tests/ClaudeRunnerCancellationTests.swift" -o "$TEMP/cancellation-tests"
"$TEMP/cancellation-tests"
