#!/bin/bash
set -euo pipefail
umask 077

if [ "$(uname -s)" != Linux ]; then
  echo "This installer requires Linux with systemd."
  exit 1
fi
if [ "$(id -u)" = 0 ]; then
  echo "Run bash install.sh as your normal login user, without sudo. The installer requests sudo only for system files."
  exit 1
fi

INSTALL_DIR="${CLOUDE_INSTALL_DIR:-/opt/cloude-agent}"
DATA_DIR="${CLOUDE_DATA:-$HOME/.cloude-agent}"
SYSTEMD_DIR="${CLOUDE_SYSTEMD_DIR:-/etc/systemd/system}"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_USER="$(id -un)"
INSTALL_GROUP="$(id -gn)"
for value in "$INSTALL_DIR" "$DATA_DIR" "$SYSTEMD_DIR" "$HOME"; do
  if [[ "$value" != /* || "$value" =~ [[:space:]\%\"\\] ]]; then
    echo "Install and home paths must be absolute and cannot contain whitespace, quotes, percent signs, or backslashes."
    exit 1
  fi
done
if [ "$INSTALL_DIR" = / ] || [ -L "$INSTALL_DIR" ]; then
  echo "Choose a dedicated, non-symlink install directory."
  exit 1
fi
for command in curl tar git systemctl sudo sha256sum flock; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Missing $command. On Ubuntu: sudo apt install curl tar git systemd sudo coreutils util-linux"
    exit 1
  fi
done

NODE_MAJOR=0
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
fi
if [ "$NODE_MAJOR" -lt 22 ]; then
  case "$(uname -m)" in
    x86_64|amd64) NODE_ARCH=x64; NODE_SHA=07c8aafa60644fb81adefa1ee7da860eb1920851ffdc9a37020ab0be47fbc10e ;;
    aarch64|arm64) NODE_ARCH=arm64; NODE_SHA=1d1690e9aba47e887a275abc6d8f7317e571a0700deaef493f768377e99155f5 ;;
    *) echo "Install Node.js 22 or newer for this architecture first."; exit 1 ;;
  esac
  NODE_TEMP=$(mktemp -d)
  trap 'rm -rf "$NODE_TEMP"' EXIT
  curl -fsSL "https://nodejs.org/dist/v22.22.1/node-v22.22.1-linux-$NODE_ARCH.tar.gz" -o "$NODE_TEMP/node.tar.gz"
  printf '%s  %s\n' "$NODE_SHA" "$NODE_TEMP/node.tar.gz" | sha256sum --check --status
  sudo tar -xzf "$NODE_TEMP/node.tar.gz" -C /usr/local --strip-components=1 --no-same-owner
  export PATH="/usr/local/bin:$PATH"
fi
export PATH="$HOME/.local/bin:$PATH:/usr/local/bin:/usr/bin:/bin"
NODE_BIN=$(command -v node)
if ! command -v npm >/dev/null 2>&1; then
  echo "Install npm alongside Node.js, then run this installer again."
  exit 1
fi
if ! command -v codex >/dev/null 2>&1 || ! codex --version | node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{const v=s.match(/\d+\.\d+\.\d+/)?.[0];process.exit(v&&v.localeCompare("0.153.4",undefined,{numeric:true})>=0?0:1)})'; then
  npm install --global --prefix "$HOME/.local" @openai/codex@0.153.4
fi
if [ "${CLOUDE_INSTALL_CLAUDE:-0}" = 1 ] && ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

sudo mkdir -p "$INSTALL_DIR" "$SYSTEMD_DIR"
sudo chown "$INSTALL_USER:$INSTALL_GROUP" "$INSTALL_DIR"
for entry in src scripts index.js package.json package-lock.json install.sh README.md; do
  if [ -e "$INSTALL_DIR/$entry" ] || [ -L "$INSTALL_DIR/$entry" ]; then
    if [ -L "$INSTALL_DIR/$entry" ]; then
      echo "Remove the unexpected code symlink at $INSTALL_DIR/$entry before installing."
      exit 1
    fi
    sudo chown -R -h "$INSTALL_USER:$INSTALL_GROUP" "$INSTALL_DIR/$entry"
    sudo chmod -R u+rwX "$INSTALL_DIR/$entry"
  fi
done
mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"
if [ "$SOURCE_DIR" != "$(cd "$INSTALL_DIR" && pwd)" ]; then
  for entry in src scripts index.js package.json package-lock.json install.sh README.md; do
    cp -R "$SOURCE_DIR/$entry" "$INSTALL_DIR/"
  done
fi
(cd "$INSTALL_DIR" && npm ci --omit=dev --ignore-scripts --no-audit --no-fund)

PAIRING_URL=""
if [ "${CLOUDE_TUNNEL:-1}" = 1 ]; then
  if ! command -v cloudflared >/dev/null 2>&1; then
    case "$(uname -m)" in
      x86_64|amd64) CF_ARCH=amd64 ;;
      aarch64|arm64) CF_ARCH=arm64 ;;
      *) echo "Install cloudflared for this architecture first."; exit 1 ;;
    esac
    CF_RELEASE=$("$NODE_BIN" --input-type=module -e '
      const response = await fetch("https://api.github.com/repos/cloudflare/cloudflared/releases/latest", { signal: AbortSignal.timeout(15000) })
      if (!response.ok) throw new Error(`cloudflared release lookup failed (${response.status})`)
      const asset = (await response.json()).assets?.find(value => value.name === `cloudflared-linux-${process.argv[1]}`)
      if (!asset || !/^sha256:[a-f0-9]{64}$/.test(asset.digest || "") || !asset.browser_download_url.startsWith("https://github.com/cloudflare/cloudflared/releases/download/")) throw new Error("cloudflared release has no verified SHA256 digest")
      process.stdout.write(`${asset.browser_download_url} ${asset.digest.slice(7)}`)
    ' "$CF_ARCH")
    read -r CF_URL CF_SHA <<< "$CF_RELEASE"
    curl -fsSL "$CF_URL" -o "$INSTALL_DIR/cloudflared.download"
    printf '%s  %s\n' "$CF_SHA" "$INSTALL_DIR/cloudflared.download" | sha256sum --check --status
    sudo install -m 755 "$INSTALL_DIR/cloudflared.download" /usr/local/bin/cloudflared
    rm "$INSTALL_DIR/cloudflared.download"
  fi
  export CLOUDE_DATA="$DATA_DIR"
  PROVISION_OUT=$("$NODE_BIN" "$INSTALL_DIR/scripts/provision.js")
  PAIRING_URL=$(printf '%s' "$PROVISION_OUT" | "$NODE_BIN" -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>process.stdout.write(JSON.parse(s).pairingURL))')
  sudo tee "$SYSTEMD_DIR/cloude-tunnel.service" > /dev/null <<UNIT
[Unit]
Description=Afto secure tunnel
After=network-online.target cloude-agent.service
Requires=cloude-agent.service

[Service]
Type=simple
User=$INSTALL_USER
Environment="HOME=$HOME"
Environment="CLOUDE_DATA=$DATA_DIR"
Environment="PATH=$PATH"
ExecStart=/bin/bash $INSTALL_DIR/scripts/run-tunnel.sh
Restart=always
RestartSec=5
UMask=0077

[Install]
WantedBy=multi-user.target
UNIT
fi

sudo tee "$SYSTEMD_DIR/cloude-agent.service" > /dev/null <<UNIT
[Unit]
Description=Afto remote coding agents
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$INSTALL_USER
Environment="HOME=$HOME"
Environment="CLOUDE_PORT=8765"
Environment="CLOUDE_HOST=127.0.0.1"
Environment="CLOUDE_DATA=$DATA_DIR"
Environment="PATH=$PATH"
WorkingDirectory=$INSTALL_DIR
ExecStart=$NODE_BIN $INSTALL_DIR/index.js
Restart=always
RestartSec=5
UMask=0077
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
UNIT

if [ "${CLOUDE_INSTALL_WHISPER:-0}" = 1 ]; then
  bash "$INSTALL_DIR/scripts/install-whisper.sh"
fi
sudo systemctl daemon-reload
sudo systemctl enable cloude-agent
sudo systemctl restart cloude-agent
if [ "${CLOUDE_TUNNEL:-1}" = 1 ]; then
  sudo systemctl enable cloude-tunnel
  sudo systemctl restart cloude-tunnel
fi

echo "Afto installed. Sign in as $INSTALL_USER: codex login --device-auth"
echo "Use an existing ChatGPT subscription. API key accounts are rejected."
echo "Data, pairing identity, and existing voice models are preserved in upgrades."
if [ -n "$PAIRING_URL" ]; then
  echo "Pairing URL: $PAIRING_URL"
  if command -v qrencode >/dev/null 2>&1; then
    qrencode -t ansiutf8 "$PAIRING_URL"
  fi
else
  echo "Local endpoint: http://127.0.0.1:8765. Token file: $DATA_DIR/auth-token"
fi
