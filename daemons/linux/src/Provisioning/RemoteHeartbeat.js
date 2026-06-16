import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { loadOrCreateIdentity } from './Identity.js'
import { putHeartbeat } from './RemoteTunnelClient.js'

const HEARTBEAT_INTERVAL_MS = 60 * 1000

export function startRemoteHeartbeat() {
  const dataDirectory = process.env.CLOUDE_DATA || path.join(os.homedir(), '.cloude-agent')
  if (fs.existsSync(path.join(dataDirectory, 'tunnel.json'))) {
    const identity = loadOrCreateIdentity()
    console.log(`[RemoteHeartbeat] starting, every ${HEARTBEAT_INTERVAL_MS / 1000}s`)
    const beat = () =>
      putHeartbeat(identity)
        .then((ok) => {
          if (!ok) console.log('[RemoteHeartbeat] heartbeat rejected')
        })
        .catch((e) => console.log(`[RemoteHeartbeat] heartbeat failed: ${e.message}`))
    beat()
    setInterval(beat, HEARTBEAT_INTERVAL_MS)
  }
}
