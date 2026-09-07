#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-native-speech-handler.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc -emit-library -emit-module -module-name Speech "$ROOT/tests/transcribe-handler/"SF*.swift \
  "$ROOT/tests/transcribe-handler/SpeechFixture.swift" -emit-module-path "$TEMP/Speech.swiftmodule" -o "$TEMP/libSpeech.dylib"
swiftc -I "$TEMP" -L "$TEMP" -lSpeech "$ROOT/src/Handlers/TranscribeHandler.swift" "$ROOT/src/TranscriptionOperation.swift" \
  "$ROOT/src/Networking/HTTPRequest.swift" "$ROOT/src/Networking/HTTPRequestCancellation.swift" \
  "$ROOT/src/Networking/HTTPResponse.swift" "$ROOT/src/Routing/RouteMatcher.swift" \
  "$ROOT/tests/transcribe-handler/DaemonVersion.swift" "$ROOT/tests/transcribe-handler/DaemonCapabilities.swift" \
  "$ROOT/tests/transcribe-handler/TranscribeHandlerTests.swift" -o "$TEMP/transcribe-tests"
"$TEMP/transcribe-tests"
