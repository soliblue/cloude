import { createHash, randomUUID } from 'node:crypto'
import { access, stat } from 'node:fs/promises'
import { constants } from 'node:fs'
import path from 'node:path'
import SubscriptionPolicy from '../Runtime/SubscriptionPolicy.js'
import { codexClient } from './CodexClient.js'

export default class CodexTerminal {
  constructor(client, { now = Date.now, bufferLimit = 1024 * 1024, retainedMs = 600000 } = {}) {
    this.client = client
    this.now = now
    this.bufferLimit = bufferLimit
    this.retainedMs = retainedMs
    this.generation = 0
    this.closed = false
    this.entries = new Map()
    this.starts = new Map()
    this.onNotification = ({ method, params }) => {
      const entry = this.entries.get(params?.processId)
      if (method === 'command/exec/outputDelta' && entry?.status === 'running') {
        const bytes = Buffer.from(params.deltaBase64, 'base64')
        for (let offset = 0; offset < bytes.length || offset === 0; offset += 32768) {
          this.emit(entry, { type: 'terminal_output', deltaBase64: bytes.subarray(offset, offset + 32768).toString('base64'), stream: params.stream, capReached: params.capReached })
        }
      }
    }
    this.onDisconnect = () => {
      this.generation += 1
      for (const entry of this.entries.values()) { this.finish(entry, 'failed', { error: 'The host connection ended. Open a new terminal.' }) }
    }
    client.on('notification', this.onNotification)
    client.on('disconnected', this.onDisconnect)
    this.timer = setInterval(() => this.sweep(), 30000)
    this.timer.unref()
  }

  snapshot(entry) {
    return { terminalId: entry.terminalId, sessionId: entry.sessionId, path: entry.path, status: entry.status, exitCode: entry.exitCode, error: entry.error, lastSeq: entry.seq, createdAt: entry.createdAt, cols: entry.cols, rows: entry.rows }
  }

  list(sessionId) { return [...this.entries.values()].filter(entry => entry.sessionId === sessionId.toLowerCase()).map(entry => this.snapshot(entry)) }
  get(sessionId, terminalId) { const entry = this.entries.get(terminalId); return entry?.sessionId === sessionId.toLowerCase() ? entry : null }

  async start(sessionId, body) {
    const key = `${sessionId.toLowerCase()}:${body.requestId}`
    const fingerprint = JSON.stringify([body.path, body.cols || 80, body.rows || 24])
    if (this.starts.has(key)) {
      const existing = this.starts.get(key)
      if (existing.fingerprint !== fingerprint) { return { status: 409, body: { error: 'This request ID already belongs to a different terminal.' } } }
      return existing.promise.then(result => existing.terminalId && this.entries.has(existing.terminalId) ? { status: 200, body: this.snapshot(this.entries.get(existing.terminalId)) } : result)
    }
    if ([...this.entries.values()].filter(entry => entry.status === 'running').length + [...this.starts.values()].filter(entry => !entry.terminalId).length >= 4) { return { status: 409, body: { error: 'Close a terminal before opening another. This endpoint supports four at once.' } } }
    const start = { fingerprint }
    this.starts.set(key, start)
    start.promise = this.create(sessionId, body, key).then(result => {
      if (result.body.terminalId) { start.terminalId = result.body.terminalId } else { this.starts.delete(key) }
      return result
    })
    return start.promise
  }

  async create(sessionId, body, key) {
    const generation = this.generation
    return Promise.all([stat(body.path), this.client.request('account/read', { refreshToken: false }), this.client.request('config/read', { cwd: body.path, includeLayers: false })]).then(async ([directory, account, config]) => {
      if (this.closed || generation !== this.generation) { return { status: 502, body: { error: 'The host connection changed while opening this terminal. Retry the request.' } } }
      if (!directory.isDirectory()) { return { status: 400, body: { error: 'Choose an existing working directory.' } } }
      SubscriptionPolicy.codex(account, config, {}, { capacity: false })
      const shell = path.isAbsolute(process.env.SHELL || '') && await Promise.all([access(process.env.SHELL, constants.X_OK), stat(process.env.SHELL)]).then(([, file]) => file.isFile(), () => false) ? process.env.SHELL : '/bin/sh'
      const entry = { cols: body.cols || 80, rows: body.rows || 24, writes: new Map(), inputQueue: Promise.resolve(), terminalId: randomUUID(), sessionId: sessionId.toLowerCase(), path: body.path, key, status: 'running', seq: -1, createdAt: this.now(), touchedAt: this.now(), events: [], bytes: 0, subscribers: new Set() }
      this.entries.set(entry.terminalId, entry)
      this.emit(entry, { type: 'terminal_state', ...this.snapshot(entry) })
      this.client.request('command/exec', { command: [shell, '-i'], env: { TERM: 'xterm-256color', COLORTERM: 'truecolor' }, cwd: body.path, processId: entry.terminalId, tty: true, streamStdin: true, streamStdoutStderr: true, size: { cols: body.cols || 80, rows: body.rows || 24 }, sandboxPolicy: { type: 'dangerFullAccess' }, disableTimeout: true, disableOutputCap: true }, null).then(result => this.finish(entry, 'exited', { exitCode: result.exitCode }), () => {
        this.finish(entry, 'failed', { error: 'The terminal stopped or could not start. Open a new terminal to continue.' })
      })
      return { status: 202, body: this.snapshot(entry) }
    }).catch(() => ({ status: 502, body: { error: 'Cannot open this terminal. Check its directory and sign in to Codex with your ChatGPT subscription.' } }))
  }

  emit(entry, event) {
    entry.seq += 1
    const line = `${JSON.stringify({ ...event, ...(event.type === 'terminal_state' ? { lastSeq: entry.seq } : {}), seq: entry.seq })}\n`
    entry.events.push({ seq: entry.seq, line })
    entry.bytes += Buffer.byteLength(line)
    while (entry.bytes > this.bufferLimit && entry.events.length > 1) { entry.bytes -= Buffer.byteLength(entry.events.shift().line) }
    for (const subscriber of entry.subscribers) {
      if (!subscriber.write(line)) { subscriber.end(); entry.subscribers.delete(subscriber) }
    }
  }

  finish(entry, status, extra = {}) {
    if (entry.status === 'running') {
      Object.assign(entry, { status, ...extra, endedAt: this.now() })
      this.emit(entry, { type: 'terminal_state', ...this.snapshot(entry) })
      for (const subscriber of entry.subscribers) { subscriber.end() }
      entry.subscribers.clear()
    }
  }

  subscribe(entry, afterSeq, response) {
    entry.touchedAt = this.now()
    if (afterSeq < (entry.events[0]?.seq ?? 0) - 1) { response.write(`${JSON.stringify({ type: 'terminal_gap', firstSeq: entry.events[0].seq, requestedAfterSeq: afterSeq })}\n`) }
    for (const event of entry.events) {
      if (event.seq > afterSeq && !response.write(event.line)) { response.end(); return }
    }
    if (!response.write(`${JSON.stringify({ type: 'terminal_ready', ...this.snapshot(entry) })}\n`)) { response.end(); return }
    if (entry.status !== 'running') { response.end(); return }
    entry.subscribers.add(response)
    const heartbeat = setInterval(() => {
      entry.touchedAt = this.now()
      if (!response.write('\n')) { response.end() }
    }, 15000)
    heartbeat.unref()
    response.once('close', () => { clearInterval(heartbeat); entry.subscribers.delete(response) })
  }

  async control(entry, action, body) {
    if (entry.status !== 'running') { return { status: 409, body: { error: 'This terminal has ended. Open a new terminal.' } } }
    entry.touchedAt = this.now()
    return this.client.request(`command/exec/${action}`, { processId: entry.terminalId, ...body }).then(() => { if (action === 'resize') { Object.assign(entry, body.size); this.emit(entry, { type: 'terminal_state', ...this.snapshot(entry) }) }; return { status: 200, body: this.snapshot(entry) } }).catch(() => ({ status: 502, body: { error: 'The terminal did not accept this action. Check its state before retrying.' } }))
  }

  input(entry, body) {
    const fingerprint = createHash('sha256').update(JSON.stringify([body.deltaBase64 || '', body.closeStdin === true])).digest('hex')
    const existing = entry.writes.get(body.writerId)
    if (existing && body.sequence === existing.sequence) {
      return existing.fingerprint === fingerprint ? existing.promise : Promise.resolve({ status: 409, body: { error: 'This input sequence was already used for different bytes.' } })
    }
    if (body.sequence !== (existing ? existing.sequence + 1 : 0)) { return Promise.resolve({ status: 409, body: { error: 'Input sequence is out of order. Refresh the terminal before continuing.' } }) }
    if (!existing && entry.writes.size >= 64) { return Promise.resolve({ status: 409, body: { error: 'This terminal has reached its connected writer limit. Use an existing terminal view or open a new terminal.' } }) }
    if ((entry.pendingInputs || 0) >= 64) { return Promise.resolve({ status: 429, body: { error: 'Terminal input is busy. Retry this same sequence when earlier writes finish.' } }) }
    entry.pendingInputs = (entry.pendingInputs || 0) + 1
    const promise = entry.inputQueue.then(() => this.control(entry, 'write', { ...(body.deltaBase64 === undefined ? {} : { deltaBase64: body.deltaBase64 }), ...(body.closeStdin === undefined ? {} : { closeStdin: body.closeStdin }) })).finally(() => { entry.pendingInputs -= 1 })
    entry.inputQueue = promise.then(() => {})
    entry.writes.set(body.writerId, { sequence: body.sequence, fingerprint, promise })
    return promise
  }

  sweep() {
    for (const entry of this.entries.values()) {
      if (entry.status !== 'running' && this.now() - entry.endedAt >= this.retainedMs) { this.entries.delete(entry.terminalId); this.starts.delete(entry.key) }
    }
  }

  close() {
    this.closed = true
    clearInterval(this.timer)
    this.client.off('notification', this.onNotification)
    this.client.off('disconnected', this.onDisconnect)
    this.onDisconnect()
  }
}

export const codexTerminal = new CodexTerminal(codexClient)
