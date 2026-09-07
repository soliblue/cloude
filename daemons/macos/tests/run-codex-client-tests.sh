#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
build="$(mktemp -d /tmp/afto-codex-client-tests.XXXXXX)"
capture="$build/codex-home"
trap 'rm -rf "$build"' EXIT
chmod +x "$root/daemons/macos/tests/fake-codex-app-server.py"
swiftc "$root/daemons/macos/src/DaemonLifecycle.swift" "$root/daemons/macos/src/CodexClient.swift" "$root/daemons/macos/tests/CodexClientTests.swift" -o "$build/CodexClientTests"
CODEX_HOME="$capture" OPENAI_API_KEY="test-openai-key" ANTHROPIC_API_KEY="test-anthropic-key" "$build/CodexClientTests" "$root/daemons/macos/tests/fake-codex-app-server.py" "$capture"
