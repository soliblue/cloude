#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/ChatTranscriptionService.swift tests/chat-transcription/*.swift -o "$test_dir/chat-transcription-tests"
"$test_dir/chat-transcription-tests"
swiftc -parse-as-library -swift-version 6 -warnings-as-errors -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Chat/Logic/ChatVoice*.swift tests/chat-transcription/Endpoint.swift tests/chat-voice/*.swift \
  -o "$test_dir/voice-tests"
"$test_dir/voice-tests"
swiftc -emit-library -emit-module -module-name Speech -target "$(uname -m)-apple-macosx14.0" \
  tests/local-transcription/Speech.swift -o "$test_dir/libSpeech.dylib" -emit-module-path "$test_dir/Speech.swiftmodule"
swiftc -parse-as-library -swift-version 6 -warnings-as-errors -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  -I "$test_dir" -L "$test_dir" -lSpeech -Xlinker -rpath -Xlinker "$test_dir" \
  src/Features/Chat/Logic/ChatLocalTranscription.swift src/Features/Chat/Logic/ChatTranscriptionAudio.swift \
  tests/local-transcription/main.swift -o "$test_dir/local-speech-tests"
"$test_dir/local-speech-tests"
swiftc -emit-library -emit-module -module-name AVFoundation -target "$(uname -m)-apple-macosx14.0" \
  tests/audio-recorder/AVFoundation.swift -o "$test_dir/libAVFoundation.dylib" -emit-module-path "$test_dir/AVFoundation.swiftmodule"
swiftc -parse-as-library -swift-version 6 -warnings-as-errors -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  -I "$test_dir" -L "$test_dir" -lAVFoundation -Xlinker -rpath -Xlinker "$test_dir" \
  src/Features/Chat/Logic/ChatAudioRecorder.swift tests/audio-recorder/main.swift -o "$test_dir/recorder-tests"
"$test_dir/recorder-tests"
