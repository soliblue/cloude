#!/usr/bin/env node
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { loadOrCreateIdentity } from '../src/Provisioning/Identity.js'
import { putMac, putTunnel } from '../src/Provisioning/RemoteTunnelClient.js'
import { daemonToken } from '../src/Routing/DaemonAuth.js'

const dataDirectory = process.env.CLOUDE_DATA || path.join(os.homedir(), '.cloude-agent')
const tunnelFile = path.join(dataDirectory, 'tunnel.json')
const displayName = process.env.CLOUDE_DISPLAY_NAME || os.hostname()

const identity = loadOrCreateIdentity()

if (!(await putMac(identity, displayName))) {
  console.error('Provisioning failed: could not register host')
  process.exit(1)
}

const tunnel = await putTunnel(identity)
if (!tunnel) {
  console.error('Provisioning failed: backend did not return a tunnel')
  process.exit(1)
}

fs.writeFileSync(tunnelFile, JSON.stringify(tunnel, null, 2), { mode: 0o600 })

const token = daemonToken()
const params = new URLSearchParams({
  host: tunnel.hostname,
  port: '443',
  token,
  name: displayName,
})
const pairingURL = `cloude://pair?${params.toString()}`

console.log(JSON.stringify({ hostname: tunnel.hostname, pairingURL }))
