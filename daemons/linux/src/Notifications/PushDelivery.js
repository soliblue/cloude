import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import { randomUUID } from 'node:crypto'
import { loadOrCreateIdentity } from '../Provisioning/Identity.js'

export default class PushDelivery {
  constructor({ directory = process.env.CLOUDE_DATA || path.join(os.homedir(), '.cloude-agent'), baseURL = process.env.CLOUDE_PROVISIONING_URL || 'https://remotecc.soli.blue', identity = loadOrCreateIdentity, transport = fetch } = {}) {
    this.directory = directory
    this.baseURL = baseURL
    this.identity = identity
    this.transport = transport
    this.file = path.join(directory, 'push-queue.json')
    this.quarantinePending = false
    this.dirty = false
    this.queue = this.restore()
    this.flushing = false
    this.timer = null
  }

  restore() {
    if (fs.existsSync(this.file)) {
      try {
        const entries = JSON.parse(fs.readFileSync(this.file, 'utf8'))
        if (!Array.isArray(entries) || !entries.every((entry) => this.validEntry(entry)) || new Set(entries.map(([key]) => key)).size !== entries.length || new Set(entries.map(([, value]) => value.id)).size !== entries.length) {
          throw new Error('Invalid push queue')
        }
        return new Map(entries)
      } catch {
        this.quarantinePending = true
        this.quarantine()
      }
    }
    return new Map()
  }

  validEntry(entry) {
    if (Array.isArray(entry) && entry.length === 2 && typeof entry[0] === 'string' && entry[0].length > 0 && entry[0].length <= 512) {
      const value = entry[1]
      const body = value?.body
      if (value && !Array.isArray(value) && typeof value.id === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(value.id) && Number.isSafeInteger(value.createdAt) && value.createdAt >= 0 && body && typeof body === 'object' && !Array.isArray(body)) {
        if (value.method === 'POST' && value.route === '/notifications') {
          return (body.scheduleId === undefined && body.runId === undefined || ['sessionId', 'scheduleId', 'runId'].every(key => typeof body[key] === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(body[key]))) && typeof body.sessionId === 'string' && body.sessionId.length > 0 && typeof body.title === 'string' && typeof body.body === 'string' && ['completed', 'failed', 'attention'].includes(body.kind)
        }
        if (value.method === 'PUT' && typeof value.route === 'string' && /^\/push-devices\/[A-Za-z0-9-]{1,128}$/.test(value.route)) {
          return body.deviceId === value.route.slice('/push-devices/'.length) && typeof body.token === 'string' && /^[a-f0-9]{32,512}$/i.test(body.token) && ['sandbox', 'production'].includes(body.environment) && body.bundleId === 'soli.Cloude'
        }
      }
    }
    return false
  }

  quarantine() {
    try {
      if (fs.existsSync(this.file)) {
        const backup = `${this.file}.corrupt-${Date.now()}-${randomUUID()}`
        fs.chmodSync(this.file, 0o600)
        fs.renameSync(this.file, backup)
        console.warn('[PushDelivery] invalid queue quarantined; starting empty')
      }
      this.quarantinePending = false
      return true
    } catch {
      console.warn('[PushDelivery] invalid queue preserved; waiting for writable storage')
      return false
    }
  }

  get available() {
    return fs.existsSync(path.join(this.directory, 'tunnel.json'))
  }

  enqueue(key, method, route, body) {
    const entry = [key, { id: randomUUID(), method, route, body, createdAt: Date.now() }]
    if (this.available && this.validEntry(entry)) {
      this.queue.set(...entry)
      if (this.persist()) {
        this.flush().catch(() => {})
        return true
      }
    }
    return false
  }

  cancel(key) {
    if (this.queue.delete(key)) { this.persist() }
  }

  persist() {
    this.dirty = true
    if (this.quarantinePending && !this.quarantine()) { return false }
    try {
      fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 })
      fs.writeFileSync(`${this.file}.tmp`, JSON.stringify([...this.queue]), { mode: 0o600 })
      fs.renameSync(`${this.file}.tmp`, this.file)
      this.dirty = false
      return true
    } catch {
      console.warn('[PushDelivery] queue storage unavailable; waiting to retry')
      return false
    }
  }

  async flush() {
    if (this.dirty && !this.persist()) { return }
    if (!this.flushing && this.available && this.queue.size > 0) {
      this.flushing = true
      await Promise.resolve().then(async () => {
      const identity = this.identity()
      for (const [key, entry] of [...this.queue].sort((a, b) => Number(b[1].method === 'PUT') - Number(a[1].method === 'PUT')).slice(0, 25)) {
        const response = await this.transport(`${this.baseURL}/macs/${encodeURIComponent(identity.installationId)}${entry.route}`, {
          method: entry.method,
          headers: { 'Content-Type': 'application/json', 'X-Mac-Secret': identity.secret },
          body: JSON.stringify({ ...entry.body, eventId: entry.id }),
          signal: AbortSignal.timeout(15000)
        }).catch(() => null)
        if ((response?.ok || response?.status === 410 || Date.now() - entry.createdAt > 86400000) && this.queue.get(key)?.id === entry.id) {
          this.queue.delete(key)
          this.persist()
        }
        if (entry.method === 'PUT' && !response?.ok) { break }
      }
      }).finally(() => { this.flushing = false })
    }
  }

  start() {
    if (!this.timer) {
      this.flush().catch(() => {})
      this.timer = setInterval(() => this.flush().catch(() => {}), 30000)
      this.timer.unref()
    }
  }
}

export const pushDelivery = new PushDelivery()
