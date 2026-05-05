#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "🔨 Building macOS daemon release..."

TAG="macos-daemon-v$(date +%Y.%m.%d).1"

git -C "$REPO_ROOT" tag "$TAG" 2>/dev/null || {
    echo "❌ Tag $TAG already exists, trying with .2"
    TAG="macos-daemon-v$(date +%Y.%m.%d).2"
    git -C "$REPO_ROOT" tag "$TAG"
}

echo "🚀 Pushing tag $TAG to trigger GitHub Actions..."
git -C "$REPO_ROOT" push origin "$TAG"

echo "✅ Tag pushed: $TAG"
echo "Monitor the build at: https://github.com/soliblue/cloude/actions/workflows/mac-agent.yml"
