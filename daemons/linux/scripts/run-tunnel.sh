#!/bin/bash
set -euo pipefail
export CLOUDE_DATA="${CLOUDE_DATA:-$HOME/.cloude-agent}"
TOKEN=$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(require("path").join(process.env.CLOUDE_DATA,"tunnel.json"),"utf8")).tunnelToken)')
exec cloudflared tunnel run --token "$TOKEN"
