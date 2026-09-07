#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/Sources/TerminalVTTests"
cp tests/terminal-vt/main.swift "$test_dir/Sources/TerminalVTTests/main.swift"
cat > "$test_dir/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "TerminalVTTests", platforms: [.macOS(.v14)],
    dependencies: [.package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.20.0")],
    targets: [.executableTarget(name: "TerminalVTTests", dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")])])
PACKAGE
swift run --package-path "$test_dir" --scratch-path "${TMPDIR:-/tmp}/afto-terminal-vt-tests" TerminalVTTests
