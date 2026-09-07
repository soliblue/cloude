#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library src/Handlers/GitHandler.swift src/GitProcess.swift src/GitWorktreeService.swift src/CodexSessionStore.swift src/CodexPersistence.swift src/DaemonCapabilities.swift src/Networking/HTTPRequest.swift src/Networking/HTTPRequestCancellation.swift src/Networking/HTTPResponse.swift src/Routing/RouteMatcher.swift src/Version.swift tests/GitHandlerTests.swift -o "$test_dir/git-tests"
"$test_dir/git-tests"
