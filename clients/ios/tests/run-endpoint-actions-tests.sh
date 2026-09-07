#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" src/Features/Endpoints/Logic/Endpoint.swift src/Features/Endpoints/Logic/EndpointActions.swift tests/endpoint-actions/*.swift -o "$test_dir/endpoint-actions-tests"
"$test_dir/endpoint-actions-tests"
