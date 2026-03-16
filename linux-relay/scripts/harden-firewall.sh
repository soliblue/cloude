#!/bin/bash
#
# harden-firewall.sh - Lock down a Cloude relay server
#
# A VPS is exposed to the entire internet. Cloudflare Tunnel creates a safe
# path (domain -> Cloudflare edge -> tunnel -> localhost), but only if the
# raw IP is locked down. Without this, anyone who scans your IP can bypass
# Cloudflare entirely.
#
# What this script does:
#   1. Disables SSH password auth (key-only)
#   2. Opens port 80/443 only to Cloudflare IP ranges
#   3. Opens port 8765 (relay) only to localhost
#   4. Keeps port 22 open (safe with key-only auth)
#
# Run as root or with sudo.

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo"
  exit 1
fi

echo "=== SSH hardening ==="
cat > /etc/ssh/sshd_config.d/hardening.conf << 'SSHEOF'
PasswordAuthentication no
PermitRootLogin prohibit-password
SSHEOF
sshd -t && systemctl restart ssh
echo "Password auth disabled, root login key-only"

echo ""
echo "=== Firewall setup ==="
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp

echo "Removing any existing wide-open 80/443/8765 rules..."
ufw delete allow 80/tcp 2>/dev/null || true
ufw delete allow 443/tcp 2>/dev/null || true
ufw delete allow 8765/tcp 2>/dev/null || true

echo "Fetching Cloudflare IP ranges..."
CF_IPV4=$(curl -sf https://www.cloudflare.com/ips-v4/)
CF_IPV6=$(curl -sf https://www.cloudflare.com/ips-v6/)

for ip in $CF_IPV4; do
  ufw allow from "$ip" to any port 80,443 proto tcp comment "Cloudflare"
done

for ip in $CF_IPV6; do
  ufw allow from "$ip" to any port 80,443 proto tcp comment "Cloudflare"
done

ufw allow from 127.0.0.1 to any port 8765 proto tcp comment "Cloudflare Tunnel local"

echo ""
echo "=== Done ==="
echo ""
ufw status verbose
echo ""
echo "Verify:"
echo "  - SSH still works (test in another terminal before closing this one!)"
echo "  - Relay accessible: curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8765"
echo "  - Cloudflare Tunnel routes traffic through the domain, not the raw IP"
