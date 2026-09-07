#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/source/release" "$test_dir/bin" "$test_dir/work"
cat > "$test_dir/source/release/install.sh" <<'INSTALL'
test "$PWD" != "$AFTO_TEST_WORK"
printf verified > "$AFTO_TEST_MARKER"
INSTALL
tar -czf "$test_dir/fixture.tar.gz" -C "$test_dir/source" release
cat > "$test_dir/bin/curl" <<'CURL'
#!/bin/bash
set -euo pipefail
while [[ $# -gt 0 ]]; do
    if [[ "$1" == '-o' ]]; then
        cp "$AFTO_TEST_ARCHIVE" "$2"
        exit 0
    fi
    shift
done
exit 1
CURL
cat > "$test_dir/bin/sha256sum" <<'HASH'
#!/bin/bash
exec shasum -a 256 "$@"
HASH
chmod +x "$test_dir/bin/curl" "$test_dir/bin/sha256sum"
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
    src/Features/DaemonUpdate/Logic/DaemonUpdate{,Asset,VersionCompare,Service}.swift \
    tests/daemon-release/*.swift -o "$test_dir/tests"
"$test_dir/tests" "$test_dir"
export AFTO_TEST_ARCHIVE="$test_dir/fixture.tar.gz" AFTO_TEST_WORK="$test_dir/work" AFTO_TEST_MARKER="$test_dir/installed"
export PATH="$test_dir/bin:$PATH"
cd "$test_dir/work"
bash "$test_dir/valid.sh"
test -f "$test_dir/installed"
test ! -e release
rm "$test_dir/installed"
if bash "$test_dir/invalid.sh"; then
    echo 'Invalid checksum executed installer'
    exit 1
fi
test ! -e "$test_dir/installed"
test ! -e release
printf '%s\n' 'PASS actual copied installer command verifies checksum before execution and preserves current directory'
