#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/ChatDraft*.swift src/Features/Chat/Logic/ChatReference.swift \
  src/Features/Windows/Logic/SessionToast*.swift tests/chat-draft/*.swift -o "$test_dir/draft-tests"
"$test_dir/draft-tests"
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/ChatDraft*.swift src/Features/Chat/Logic/ChatReference.swift \
  src/Features/Chat/Logic/Chat{Goal,Model,Provider,Effort,PermissionMode,ModelCatalog,ModelOption,ReasoningOption}.swift \
  src/Features/Sessions/Logic/Session{,Actions,Random,Tab}.swift src/Features/Windows/Logic/Window.swift \
  src/Features/Windows/Logic/SessionToast*.swift tests/chat-draft-cleanup/*.swift -o "$test_dir/draft-cleanup-tests"
"$test_dir/draft-cleanup-tests"
swiftc -emit-library -emit-module -module-name UIKit -target "$(uname -m)-apple-macosx14.0" \
  tests/chat-draft-background/UIKit.swift -o "$test_dir/libUIKit.dylib" -emit-module-path "$test_dir/UIKit.swiftmodule"
swiftc -parse-as-library -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  -I "$test_dir" -L "$test_dir" -lUIKit -Xlinker -rpath -Xlinker "$test_dir" \
  src/Features/Chat/Logic/ChatDraft*.swift src/Features/Chat/Logic/ChatReference.swift \
  src/Features/Windows/Logic/SessionToast*.swift tests/chat-draft-background/main.swift -o "$test_dir/draft-background-tests"
"$test_dir/draft-background-tests"
