#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library src/CodexSessionStore.swift src/CodexPersistence.swift src/CodexJournal.swift src/CodexJournalReader.swift tests/CodexJournalTests.swift -o "$test_dir/journal-tests"
CLOUDE_DATA="$test_dir/state" "$test_dir/journal-tests"
