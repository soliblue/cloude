import crypto from 'node:crypto'
import { daemonToken } from './DaemonAuth.js'

export function isAuthorized(request) {
  if (request.headers.authorization?.startsWith('Bearer ')) {
    const presented = Buffer.from(request.headers.authorization.slice('Bearer '.length))
    const expected = Buffer.from(daemonToken())
    if (presented.length === expected.length) {
      return crypto.timingSafeEqual(presented, expected)
    }
  }
  return false
}
