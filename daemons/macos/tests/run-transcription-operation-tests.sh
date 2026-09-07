#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-native-transcription.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/TranscriptionOperation.swift" "$ROOT/src/Networking/HTTPRequestCancellation.swift" \
  "$ROOT/tests/TranscriptionOperationTests.swift" -o "$TEMP/transcription-tests"
"$TEMP/transcription-tests"
