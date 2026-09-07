#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-codex-resume-guard.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
chmod +x "$ROOT/tests/fake-codex-resume.py"
swiftc "$ROOT/src/DaemonLifecycle.swift" "$ROOT/src/Runner.swift" "$ROOT/src/ClaudeSubscriptionPolicy.swift" \
  "$ROOT/src/CodexRunner.swift" "$ROOT/src/CodexClient.swift" "$ROOT/src/CodexEvent.swift" \
  "$ROOT/src/CodexSteerReceiptStore.swift" \
  "$ROOT/src/CodexTerminal.swift" "$ROOT/src/CodexTerminalRequest.swift" "$ROOT/src/CodexTerminalEntry.swift" "$ROOT/src/CodexTerminalInput.swift" "$ROOT/src/CodexTerminalStart.swift" \
  "$ROOT/src/CodexReviewTarget.swift" "$ROOT/src/CodexShellCommand.swift" "$ROOT/src/CodexSubscriptionPolicy.swift" \
  "$ROOT/src/CodexJournal.swift" "$ROOT/src/CodexJournalReader.swift" "$ROOT/src/CodexJournalReplay.swift" \
  "$ROOT/src/CodexSessionStore.swift" "$ROOT/src/CodexPersistence.swift" "$ROOT/src/RunnerManager.swift" "$ROOT/src/ImageDropbox.swift" \
  "$ROOT/src/Handlers/ChatHandler.swift" "$ROOT/src/Handlers/CodexControlHandler.swift" "$ROOT/tests/CodexControlReviewStub.swift" "$ROOT/src/Handlers/SessionJSONLReplay.swift" \
  "$ROOT/tests/PushDeliveryReviewStub.swift" \
  "$ROOT/src/Networking/HTTPRequest.swift" "$ROOT/src/Networking/HTTPResponse.swift" \
  "$ROOT/src/Routing/RouteMatcher.swift" "$ROOT/src/DaemonCapabilities.swift" "$ROOT/src/Version.swift" \
  "$ROOT/tests/CodexResumeGuardTests.swift" -o "$TEMP/resume-guard-tests"
CLOUDE_DATA="$TEMP/data" CODEX_HOME="$TEMP/codex" "$TEMP/resume-guard-tests" "$ROOT/tests/fake-codex-resume.py" "$TEMP/codex"
