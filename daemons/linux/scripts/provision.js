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

let tunnel = fs.existsSync(tunnelFile) && process.env.CLOUDE_REPROVISION !== '1' ? JSON.parse(fs.readFileSync(tunnelFile, 'utf8')) : null
if (!tunnel?.hostname || !tunnel?.tunnelToken) {
  if (!(await putMac(identity, displayName))) {
    throw new Error('Provisioning failed: could not register host')
  }
  tunnel = await putTunnel(identity)
  if (!tunnel?.hostname || !tunnel?.tunnelToken) {
    throw new Error('Provisioning failed: backend did not return a tunnel')
  }
  fs.writeFileSync(tunnelFile, JSON.stringify(tunnel, null, 2), { mode: 0o600 })
}

const token = daemonToken()
const params = new URLSearchParams({
  host: tunnel.hostname,
  port: '443',
  token,
  name: displayName,
})
const pairingURL = `cloude://pair?${params.toString()}`

console.log(JSON.stringify({ hostname: tunnel.hostname, pairingURL }))
