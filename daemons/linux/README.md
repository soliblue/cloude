# Linux Relay

Node.js service that bridges the Cloude iOS app to Claude Code CLI on a Linux server. Runs as a systemd service, accepts WebSocket connections from the iOS app (through Cloudflare Tunnel), and spawns/manages Claude Code processes.

## Setup

```bash
npm install
./install.sh          # sets up systemd service
```

## Security

**Your server is a computer exposed to the entire internet.** Without hardening, anyone can scan your IP and access services directly, bypassing Cloudflare.

### The problem

```
Safe path:     phone -> cloude-medina.soli.blue -> Cloudflare edge -> tunnel -> localhost:8765
Unsafe path:   attacker -> 178.x.x.x:8765 -> direct access, no protection
```

Cloudflare Tunnel creates a reverse connection from your server to Cloudflare's edge. Traffic through the domain gets DDoS protection, WAF, rate limiting. But if your ports are open to the world, attackers skip all of that by hitting the IP directly.

### The fix

Run the hardening script:

```bash
sudo ./scripts/harden-firewall.sh
```

This does three things:

1. **SSH**: Disables password auth. Key-only access. Brute force becomes impractical.
2. **Ports 80/443**: Only accepts connections from [Cloudflare's IP ranges](https://www.cloudflare.com/ips/). Everyone else gets dropped.
3. **Port 8765** (relay): Only accepts connections from localhost. The Cloudflare Tunnel connects internally, so external access is unnecessary.

After hardening, the only way to reach your server is through Cloudflare (for web/WebSocket) or with your SSH key (for admin). The raw IP becomes a dead end.

### Verify

```bash
# Check firewall
sudo ufw status verbose

# Check SSH config
sudo sshd -T | grep passwordauthentication
# should print: passwordauthentication no

# Check relay is accessible locally
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8765
# should print: 426 (WebSocket upgrade expected)
```

### Updating Cloudflare IPs

Cloudflare publishes their IP ranges at https://www.cloudflare.com/ips/. If they add new ranges, re-run the hardening script. It fetches the latest list automatically.
