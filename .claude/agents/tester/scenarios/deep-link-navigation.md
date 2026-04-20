# Deep Link Navigation

Verify that file, repo, and git-diff deep links open the correct surfaces.

Resolve the repo root once:

```bash
REPO="$(git rev-parse --show-toplevel)"
```

1. Open a file deep link:

```bash
xcrun simctl openurl booted "cloude://file${REPO}/README.md"
```

2. Open a repo deep link:

```bash
xcrun simctl openurl booted "cloude://git?path=${REPO}"
```

3. Open a git-diff deep link:

```bash
xcrun simctl openurl booted "cloude://git/diff?path=${REPO}&file=clients/ios/Cloude/Features/Workspace/Utils/WorkspaceActions.swift&staged=false"
```

## Assertions

- each deep link opens the expected surface
- no stale state carried between links
- back navigation works
