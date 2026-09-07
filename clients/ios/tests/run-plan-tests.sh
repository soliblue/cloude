#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/Chat{PlanActions,Message,Reference,ReviewKind,ReviewTarget}.swift \
  tests/plans/*.swift -o "$test_dir/plan-tests"
"$test_dir/plan-tests"
swiftc -parse-as-library -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/Chat{PlanService,Message,Draft,DraftImage,DraftStore,DraftRecord,DraftDisk,DraftService,Reference,Goal,Model,Provider,Effort,PermissionMode,ReviewKind,ReviewTarget,ModelCatalog,ModelOption,ReasoningOption}.swift \
  src/Features/Sessions/Logic/Session{,Actions,Random,Tab}.swift \
  src/Features/Windows/Logic/{Window,SessionToast,SessionToastStore}.swift \
  tests/chat-draft-cleanup/{ChatActions,GitActions,SessionRemoteThread}.swift tests/plan-implementation/*.swift \
  -o "$test_dir/plan-implementation-tests"
"$test_dir/plan-implementation-tests"
