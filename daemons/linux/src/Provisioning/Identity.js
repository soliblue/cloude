import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const dataDirectory = process.env.CLOUDE_DATA || path.join(os.homedir(), '.cloude-agent')
const identityFile = path.join(dataDirectory, 'identity.json')

export function identityPath() {
  return identityFile
}

export function loadOrCreateIdentity() {
  fs.mkdirSync(dataDirectory, { recursive: true })
  if (fs.existsSync(identityFile)) {
    const parsed = JSON.parse(fs.readFileSync(identityFile, 'utf8'))
    if (parsed.installationId && parsed.secret) {
      return parsed
    }
  }
  const identity = {
    installationId: crypto.randomUUID(),
    secret: crypto.randomBytes(32).toString('hex'),
  }
  fs.writeFileSync(identityFile, JSON.stringify(identity, null, 2), { mode: 0o600 })
  return identity
}
