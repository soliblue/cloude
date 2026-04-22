import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const dataDirectory = process.env.CLOUDE_DATA || path.join(os.homedir(), '.cloude-agent')
const tokenFile = path.join(dataDirectory, 'auth-token')
let cachedToken = null

export function daemonTokenPath() {
  return tokenFile
}

export function daemonToken() {
  if (cachedToken) {
    return cachedToken
  }
  fs.mkdirSync(dataDirectory, { recursive: true })
  if (fs.existsSync(tokenFile)) {
    cachedToken = fs.readFileSync(tokenFile, 'utf8').trim()
    if (cachedToken) {
      return cachedToken
    }
  }
  cachedToken = crypto.randomBytes(32).toString('base64')
  fs.writeFileSync(tokenFile, cachedToken, { mode: 0o600 })
  return cachedToken
}
