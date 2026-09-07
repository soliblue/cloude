#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Push/Logic/PushRegistrationKey.swift src/Features/Push/Logic/PushRegistrationCore.swift tests/push/PushRegistrationCoreTests.swift \
  -o "$test_dir/push-registration-tests"
"$test_dir/push-registration-tests"
