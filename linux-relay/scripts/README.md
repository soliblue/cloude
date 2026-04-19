# Relay scripts

## `harden-firewall.sh`

Locks down a VPS so traffic can only enter through the Cloudflare tunnel. The raw IP must be inaccessible — otherwise scanners can bypass Cloudflare's DDoS/WAF protections.

What it does:
- Disable SSH password auth (key-only)
- Firewall: deny all incoming by default
- Allow SSH (key-only)
- Allow HTTP/S only from Cloudflare IP ranges
- Allow the relay port only from localhost

Run on a fresh VPS before exposing the relay.
