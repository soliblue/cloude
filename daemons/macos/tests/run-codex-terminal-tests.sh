#!/bin/zsh
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
build="$(mktemp -d /tmp/afto-codex-terminal-tests.XXXXXX)"
chmod +x "$root/daemons/macos/tests/fake-codex-terminal.py"
swiftc "$root/daemons/macos/src/DaemonLifecycle.swift" "$root/daemons/macos/src/CodexClient.swift" "$root/daemons/macos/src/CodexTerminal.swift" "$root/daemons/macos/src/CodexTerminalRequest.swift" "$root/daemons/macos/src/CodexTerminalEntry.swift" "$root/daemons/macos/src/CodexTerminalInput.swift" "$root/daemons/macos/src/CodexTerminalStart.swift" "$root/daemons/macos/src/CodexSubscriptionPolicy.swift" "$root/daemons/macos/src/CodexTerminalStream.swift" "$root/daemons/macos/src/Handlers/CodexTerminalHandler.swift" "$root/daemons/macos/src/Networking/HTTPRequest.swift" "$root/daemons/macos/src/Routing/RouteMatcher.swift" "$root/daemons/macos/src/Networking/HTTPResponse.swift" "$root/daemons/macos/src/DaemonCapabilities.swift" "$root/daemons/macos/src/Version.swift" "$root/daemons/macos/tests/CodexTerminalNetworkFixture.swift" "$root/daemons/macos/tests/CodexTerminalTests.swift" -o "$build/CodexTerminalTests"
CLOUDE_CODEX_BIN="$root/daemons/macos/tests/fake-codex-terminal.py" "$build/CodexTerminalTests"
