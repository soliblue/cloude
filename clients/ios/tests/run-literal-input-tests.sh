#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
for module in UIKit SwiftUI; do
  swiftc -emit-library -emit-module -module-name "$module" -target "$(uname -m)-apple-macosx14.0" \
    "tests/literal-input/$module.swift" -o "$test_dir/lib$module.dylib" -emit-module-path "$test_dir/$module.swiftmodule"
done
swiftc -parse-as-library -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  -I "$test_dir" -L "$test_dir" -lUIKit -lSwiftUI -Xlinker -rpath -Xlinker "$test_dir" \
  src/Core/UI/LiteralTextInput.swift src/Core/UI/LiteralTextInputCoordinator.swift \
  tests/literal-input/main.swift -o "$test_dir/literal-input-tests"
"$test_dir/literal-input-tests"
