#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "🔨 Building Linux daemon release..."

git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null
N=1
TAG="linux-daemon-v$(date +%Y.%m.%d).$N"
while git -C "$REPO_ROOT" show-ref --verify --quiet "refs/tags/$TAG"; do
    N=$((N + 1))
    TAG="linux-daemon-v$(date +%Y.%m.%d).$N"
done
git -C "$REPO_ROOT" tag "$TAG"

echo "🚀 Pushing tag $TAG to trigger GitHub Actions..."
git -C "$REPO_ROOT" push origin "$TAG"

echo "✅ Tag pushed: $TAG"
echo "Monitor the build at: https://github.com/soliblue/cloude/actions/workflows/linux-agent.yml"
