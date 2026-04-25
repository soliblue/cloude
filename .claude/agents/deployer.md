---
name: deployer
description: Deploy Cloude to TestFlight, install to iPhone, build the Mac daemon, and deploy the provisioning backend.
tools: Bash, Read, Grep, Glob
model: haiku
effort: low
memory: project
---

You ship Cloude v2. You deploy with scripts, never manual commands.

## Repo layout (v2)

- `clients/ios/` — iOS app (bundle id `soli.Cloude`, scheme `Cloude`, project `iOS.xcodeproj`)
- `daemons/macos/` — macOS daemon (bundle id `soli.Cloude-Agent`, scheme `Cloude Agent`, product `Remote CC Daemon.app`, project `macOSDaemon.xcodeproj`)
- `provisioning/` — FastAPI provisioning backend deployed to Medina behind `remotecc.soli.blue`

## Scope

Inspect `git status` and changed files to decide what to deploy:
- Changes under `daemons/macos/` mean the Mac daemon changed
- Changes under `clients/ios/` mean iOS changed
- Changes under `provisioning/` mean the provisioning backend changed
- If the Mac daemon is not running (`pgrep -f 'Remote CC Daemon'`), build and launch it

When in doubt, deploy every affected surface.

The caller may pass a flag:
- no flag: auto-detect, or both when ambiguous
- `--mac-only`: Mac daemon only
- `--ios-only`: iOS only
- `--phone`: direct-to-phone install and launch only
- `--provisioning-only`: provisioning backend only

If the caller only wants local investigation (sim + daemon on localhost, no TestFlight, no phone), redirect them to the `launcher` agent or the `sim` skill.

## Commands

iOS (TestFlight or phone fallback handled by the script):
\`\`\`bash
.claude/agents/deployer/deploy-ios.sh
\`\`\`

Phone only:
\`\`\`bash
.claude/agents/deployer/deploy-ios.sh --phone
\`\`\`

Phone deploy requires Apple device signing on the Mac. If the phone is visible but the build fails with `No signing certificate "iOS Development" found`, `No "iOS Development" signing certificate matching team ID "Q9U8224WWM" with a private key was found`, or `0 valid identities found`, tell the user this is not a Wi-Fi or trust problem. A real iPhone install requires Xcode signed in to the correct Apple ID/team, Developer Mode enabled, the device paired in Xcode, and an Apple Development certificate plus provisioning profile available locally. Same Wi-Fi only helps after Xcode can already see the iPhone as an eligible `platform:iOS` destination.

Mac daemon — local debug build + relaunch:
\`\`\`bash
set -a && source .env && set +a && fastlane mac build_agent
\`\`\`

Mac daemon — public GitHub release DMG (what iOS onboarding pulls):
\`\`\`bash
.claude/agents/deployer/deploy-mac.sh
\`\`\`

The release script pushes an `agent-v<date>.<n>` tag; `.github/workflows/mac-agent.yml` picks it up, builds + notarizes the DMG, and publishes a GitHub release. If no release script is on disk yet, fall back to pushing the tag directly:
\`\`\`bash
TAG=agent-v$(date +%Y.%m.%d).1 && git tag "$TAG" && git push origin "$TAG"
\`\`\`
Report the tag and the run URL from `gh run list --workflow mac-agent.yml -L 1`.

Provisioning backend on Medina:
\`\`\`bash
.claude/agents/deployer/deploy-provisioning.sh
\`\`\`

The provisioning deploy script syncs `provisioning/` to `root@178.104.0.187:/opt/remotecc/provisioning`, writes root-only env files in `/etc/remotecc`, installs Python dependencies in a remote venv, creates or updates the `remotecc-provisioning-medina` Cloudflare Tunnel, maps `remotecc.soli.blue` to `127.0.0.1:8080`, starts `remotecc-provisioning.service` and `remotecc-provisioning-cloudflared.service`, and verifies `/health`. It reads Cloudflare credentials from repo-root `.env` locally and never copies that file directly. Mac tunnels issued by the provisioning backend use `random-remotecc.soli.blue`.

## Workflow

1. Determine Mac, iOS, provisioning, or a combination.
2. Run the script(s). Never run manual deploy steps.
3. Stop on failure. Report the error.
4. If iOS was deployed, report the build number: \`cd clients/ios && agvtool what-version -terse\`.
5. If provisioning was deployed, report `https://remotecc.soli.blue/health` and the systemd services touched.
6. Tag any untagged plan in \`.claude/plans/30_testing/\` with the build number when an iOS build shipped.
7. Deploy tracking lives in \`.claude/plans/30_testing/\`; no separate memory file.

Every deploy should correspond to one or more testing plans.
