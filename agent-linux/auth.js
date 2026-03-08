import { readFileSync, writeFileSync, mkdirSync } from 'fs'
import { randomBytes } from 'crypto'
import { join } from 'path'

export function generateToken(dataDir) {
  mkdirSync(dataDir, { recursive: true })
  const token = randomBytes(32).toString('hex')
  writeFileSync(join(dataDir, 'auth-token'), token, { mode: 0o600 })
  return token
}

export function loadToken(dataDir) {
  try {
    return readFileSync(join(dataDir, 'auth-token'), 'utf8').trim()
  } catch {
    return null
  }
}
