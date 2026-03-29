# Cloude

Cloude lets you control Claude Code from your iPhone.

It pairs a native iOS app with a local macOS agent or a Linux relay, so you can start coding sessions remotely, watch output stream live, and work with your machine from anywhere without reducing everything to a browser tab.

## How It Works

The system has three main pieces:

- The iOS app is the client you use on your phone.
- The macOS agent runs on your Mac as a local companion.
- The Linux relay is an alternative host for remote or server-based setups.

The app connects to the agent or relay over WebSocket. For remote access, Cloudflare Tunnel is the preferred option, with Tailscale supported as an alternative.

## Mac Agent

Download the latest Mac agent DMG here:

- [Cloude Agent for macOS](https://github.com/soliblue/cloude/releases/latest/download/Cloude-Agent.dmg)

The DMG is built from GitHub Actions and published as a release asset instead of being committed into the repository.

## Repository Layout

```text
Cloude/
├── Cloude/                    # iOS app
├── Cloude Agent/              # macOS menu bar agent
├── CloudeShared/              # Shared Swift package
└── iOS/                       # iOS-specific assets
linux-relay/                   # Node.js relay
```

## TestFlight Deploys

GitHub Actions is already wired to deploy the iOS app to TestFlight.

Triggers:

- Run `Deploy to TestFlight` manually from the Actions tab with `Run workflow`
- Push a tag that matches `v*`, such as `v1.0.0`

Required GitHub repository secrets:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_CONTENT`
- `DISTRIBUTION_CERTIFICATE_BASE64`
- `DISTRIBUTION_CERTIFICATE_PASSWORD`
- `PROVISIONING_PROFILE_BASE64`

`DISTRIBUTION_CERTIFICATE_BASE64` should be the base64-encoded contents of `certs/distribution.p12`.

Example:

```sh
base64 -i certs/distribution.p12 | pbcopy
```

`PROVISIONING_PROFILE_BASE64` should be the base64-encoded contents of the App Store provisioning profile for `soli.Cloude`.

The workflow definition lives at `.github/workflows/testflight.yml`, and the Fastlane lane it runs is `fastlane ios beta_local`.

## Mac Agent DMG

GitHub Actions can also build and publish the Mac agent DMG.

Triggers:

- Run `Build Mac Agent DMG` manually from the Actions tab
- Push a tag that matches `agent-v*`

Required GitHub repository secrets:

- `MAC_DEVELOPER_ID_CERTIFICATE_BASE64`
- `MAC_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_CONTENT`

The workflow definition lives at `.github/workflows/mac-agent.yml`, and the Fastlane lane it runs is `fastlane mac release_agent`.

## Security Notes

If you run the relay on a VPS, lock down the raw IP and expose it only through the tunnel. The helper script at `linux-relay/scripts/harden-firewall.sh` sets up the intended firewall posture.
