---
name: setup
description: Set up a new hosted Cloude instance and its integrations.
user-invocable: true
metadata:
  icon: wrench.and.screwdriver.fill
  aliases: [onboard, provision]
---

# Setup

Set up a new Cloude Cloud instance or add integrations to an existing one.

## Flags

- `/setup`: check what is missing and guide setup
- `/setup github`: GitHub only
- `/setup cloudflare`: Cloudflare only
- `/setup all`: run all supported setup flows

## Baseline

Expected server baseline:
- Ubuntu 24.04
- Node.js and npm
- Python 3
- Git and SSH key pair
- Claude Code
- systemd service for the Cloude agent

## Integrations

### GitHub

1. Ensure `gh` is installed.
2. Check `gh auth status`.
3. If needed, run `gh auth login --hostname github.com --git-protocol ssh --web`.
4. Help the user complete device flow with phone-friendly copy and open steps.
5. Verify auth and configure git identity if missing.

### Cloudflare

1. Ensure Wrangler is installed.
2. Run `wrangler login` if needed.
3. Help the user complete the auth flow.
4. Verify with `wrangler whoami`.

## Status Check

When running plain `/setup`, report what is already configured and what is missing.

## Rules

- Minimize typing for the user.
- Prefer copyable URLs and codes.
- Report clear success or failure after each integration.
