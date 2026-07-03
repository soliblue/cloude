#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "🔨 Building macOS daemon release..."

N=1
while ! git -C "$REPO_ROOT" tag "macos-daemon-v$(date +%Y.%m.%d).$N" 2>/dev/null; do
    N=$((N + 1))
done
TAG="macos-daemon-v$(date +%Y.%m.%d).$N"

echo "🚀 Pushing tag $TAG to trigger GitHub Actions..."
git -C "$REPO_ROOT" push origin "$TAG"

echo "✅ Tag pushed: $TAG"
echo "Monitor the build at: https://github.com/soliblue/cloude/actions/workflows/mac-agent.yml"
