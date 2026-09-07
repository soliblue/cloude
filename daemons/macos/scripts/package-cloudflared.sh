#!/bin/bash
set -euo pipefail
version=2026.8.3
output="${1:?Pass the universal cloudflared output path}"
stage="$(mktemp -d /tmp/afto-cloudflared.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
for architecture in arm64 amd64; do
  case "$architecture" in
    arm64) digest=40c9144d86df8937c5b43293a1f7d2d2107029aa74725023dd46b1b27154352f ;;
    amd64) digest=61e1316266a00fd70ce40da011d612badc805367fb65293dd1925f938f704c99 ;;
  esac
  mkdir "$stage/$architecture"
  curl --fail --silent --show-error --location "https://github.com/cloudflare/cloudflared/releases/download/$version/cloudflared-darwin-$architecture.tgz" -o "$stage/$architecture.tgz"
  printf '%s  %s\n' "$digest" "$stage/$architecture.tgz" | shasum --algorithm 256 --check --status
  tar -xzf "$stage/$architecture.tgz" -C "$stage/$architecture"
done
mkdir -p "$(dirname "$output")"
lipo -create "$stage/arm64/cloudflared" "$stage/amd64/cloudflared" -output "$output"
lipo "$output" -verify_arch arm64 x86_64
chmod 0755 "$output"
"$output" --version
