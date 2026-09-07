#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/Chat{Goal,GoalResponse,GoalService,GoalRequestStore,Provider}.swift \
  src/Features/Sessions/Logic/SessionRemote{Thread,ThreadKey}.swift \
  tests/remote-history/{Session,Endpoint,SessionActions,HTTPClient}.swift \
  tests/goals/*.swift -o "$test_dir/goal-tests"
"$test_dir/goal-tests"
