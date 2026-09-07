#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc src/Runner.swift src/ClaudeSubscriptionPolicy.swift tests/PushDeliveryReviewStub.swift tests/runner-recording/*.swift -o "$test_dir/recording-tests"
"$test_dir/recording-tests"
