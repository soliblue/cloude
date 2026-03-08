# Setup Skill

Onboarding integrations for a new Cloude Cloud instance (hosted Linux machine). Run `/setup` when provisioning a new server or adding integrations for a user.

## Flags

- `/setup` - interactive setup, detect what's missing and guide through it
- `/setup github` - GitHub integration only
- `/setup cloudflare` - Cloudflare integration only
- `/setup all` - run all integrations sequentially

## Server Baseline

Every Cloude Cloud instance starts with:
- Ubuntu 24.04
- Node.js (LTS) + npm
- Python 3
- Git + SSH key pair (`~/.ssh/id_ed25519`)
- Claude Code (installed globally)
- systemd service running the cloude agent

## Integrations

### 1. GitHub

**Goal**: Clone and manage user's repos (public + private) from the server.

**Steps**:
1. Check if `gh` CLI is installed, install if not:
   ```bash
   sudo apt-get install -y gh
   ```
2. Check auth status:
   ```bash
   gh auth status
   ```
3. If not authenticated, start device flow:
   ```bash
   gh auth login --hostname github.com --git-protocol ssh --web
   ```
   - This prints a one-time code and a URL (https://github.com/login/device)
   - Use `cloude clipboard <code>` to copy the code to the user's phone
   - Use `cloude open https://github.com/login/device` to open the URL on their phone
   - Wait for the user to confirm they've entered the code
4. Verify auth works:
   ```bash
   gh auth status
   gh repo list --limit 5
   ```
5. Configure git identity if not set:
   ```bash
   git config --global user.name "$(gh api user -q .name)"
   git config --global user.email "$(gh api user -q .email)"
   ```

**Post-setup**: User can clone repos into `~/projects/` and push/pull freely.

### 2. Cloudflare

**Goal**: Deploy static sites, Workers, and Pages from the server.

**Steps**:
1. Install Wrangler globally:
   ```bash
   npm install -g wrangler
   ```
2. Authenticate (device flow, similar to GitHub):
   ```bash
   wrangler login
   ```
   - Copy the URL to the user's clipboard with `cloude clipboard`
   - Wait for browser confirmation
3. Verify:
   ```bash
   wrangler whoami
   ```

**Post-setup**: User can deploy with `wrangler pages deploy` or `wrangler deploy` for Workers.

### 3. Future Integrations (planned)

- **Vercel**: `npx vercel login`
- **Fly.io**: `flyctl auth login`
- **Railway**: `railway login`
- **Supabase**: `npx supabase login`
- **Docker Hub**: `docker login`

## Checking Status

When running `/setup` with no flags, check all integrations and report status:

```bash
echo "=== GitHub ===" && gh auth status 2>&1
echo "=== Cloudflare ===" && wrangler whoami 2>&1
echo "=== Git Identity ===" && git config --global user.name && git config --global user.email
echo "=== SSH Key ===" && cat ~/.ssh/id_ed25519.pub 2>/dev/null || echo "No SSH key"
echo "=== Node ===" && node --version
echo "=== Projects ===" && ls ~/projects/
```

Then offer to set up anything that's missing.

## UX Notes

- Always use `cloude clipboard` + `cloude open` to make auth flows phone-friendly
- The user is on their phone (iOS app) - minimize typing, maximize copy-paste
- Run auth commands in background with timeout so the conversation doesn't hang
- Report clear status after each integration (checkmark or what failed)
