#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library \
  src/Features/Files/Logic/File{Cache,NodeDTO,PreviewResource,PreviewContentType,PreviewService}.swift \
  tests/file-preview/*.swift -o "$test_dir/file-preview-tests"
"$test_dir/file-preview-tests"
