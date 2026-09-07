#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Sessions/Logic/Session.swift src/Features/Sessions/Logic/Session+ConnectionScope.swift src/Features/Sessions/Logic/SessionActions+Location.swift \
  src/Features/Sessions/Logic/Session{Tab,Project,ProjectRoot,ManifestStore,ManifestService,ManifestDTO}.swift src/Features/Sessions/Logic/{Skill,Agent}.swift \
  src/Features/Chat/Logic/Chat{Goal,Model,Provider,Effort,PermissionMode,AccountService,AccountStore,AccountSnapshot,UsageWindow,ModelService,ModelCatalog,ModelOption,ReasoningOption}.swift \
  tests/session-connection/*.swift -o "$test_dir/session-connection-tests"
"$test_dir/session-connection-tests"
