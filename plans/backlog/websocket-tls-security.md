# Security Improvements Plan

## Current State

### What's Secure
- **Token generation**: 256-bit cryptographically random token using `SecRandomCopyBytes`
- **Token storage**: Stored in macOS Keychain (Mac) and iOS Keychain (iPhone)
- **Authentication gate**: All commands require valid token before processing

### What's Not Secure
- **No TLS**: WebSocket server uses plain TCP (`NWParameters.tcp`)
- **Plaintext transmission**: Auth token and all messages sent unencrypted
- **Network exposure**: Server binds to all interfaces (`0.0.0.0:8765`)

### Risk Summary
| Scenario | Risk Level |
|----------|------------|
| Over Tailscale | Low - Tailscale encrypts traffic |
| Home WiFi (trusted) | Medium - Local attackers could sniff |
| Public/shared WiFi | High - Easy to intercept token |
| Exposed to internet | Critical - Do not do this |

---

## Options for Improvement

### Option 1: Recommend Tailscale (No Code Changes)
**Effort**: None (documentation only)
**Security**: High

Tailscale provides:
- End-to-end encryption via WireGuard
- Per-device certificates handled automatically
- Works across networks (not just local WiFi)

Just document that users should connect via Tailscale IP.

---

### Option 2: Add TLS with Per-Device Certificates
**Effort**: High
**Security**: High

#### Implementation Steps

1. **Mac generates unique certificate on first launch**
   ```swift
   // In AuthManager or new CertificateManager
   // Generate self-signed cert + private key
   // Store in Keychain
   ```

2. **Add certificate to WebSocketServer**
   ```swift
   // Change from:
   let parameters = NWParameters.tcp

   // To:
   let tlsOptions = NWProtocolTLS.Options()
   // Configure with generated certificate
   let parameters = NWParameters(tls: tlsOptions)
   ```

3. **Pairing flow for iPhone**
   - Mac displays QR code containing: IP + port + certificate fingerprint
   - iPhone scans QR code
   - iPhone stores trusted fingerprint for that Mac
   - On connect, iPhone verifies server cert matches fingerprint

4. **Certificate pinning in iOS app**
   ```swift
   // In ConnectionManager
   // Implement URLSessionDelegate / NWConnection TLS verification
   // Compare server cert fingerprint against stored trusted fingerprint
   ```

#### Files to Modify
- `Cloude Agent/Services/WebSocketServer.swift` - Add TLS support
- `Cloude Agent/Services/AuthManager.swift` - Or new `CertificateManager.swift`
- `Cloude Agent/UI/StatusView.swift` - Add QR code display for pairing
- `Cloude/Services/ConnectionManager.swift` - Add cert pinning
- `Cloude/UI/SettingsView.swift` - Add QR scanner for pairing

---

### Option 3: Bind to Localhost Only + SSH Tunnel
**Effort**: Low
**Security**: High (but less convenient)

1. Change server to bind to `127.0.0.1` only
2. Users connect via SSH tunnel or Tailscale

---

## Recommendation

**Short term**: Document Tailscale as the recommended secure setup. It's free, takes 5 minutes to set up, and provides better security than a custom TLS implementation.

**Long term**: If distributing the app more widely, implement Option 2 (per-device certificates with pairing flow). This provides security without requiring users to install Tailscale.

---

## Quick Wins (Low Effort)

1. **Add Tailscale detection**: Show warning if not connecting via Tailscale IP (100.x.x.x range)
2. **Add network warning**: Warn user if Mac is on public network
3. **Rate limiting**: Add basic rate limiting for auth attempts
4. **Connection timeout**: Disconnect unauthenticated connections after 30 seconds
