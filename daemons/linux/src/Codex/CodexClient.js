import { spawn } from 'node:child_process'
import { EventEmitter } from 'node:events'
import { createInterface } from 'node:readline'
import { randomUUID } from 'node:crypto'
import { spawnEnvironment } from '../Runtime/ClaudeRuntime.js'

export default class CodexClient extends EventEmitter {
  constructor({ executable = process.env.CLOUDE_CODEX_BIN || 'codex', args = ['app-server', '--listen', 'stdio://'], timeout = 60000 } = {}) {
    super()
    this.setMaxListeners(100)
    this.executable = executable
    this.args = args
    this.timeout = timeout
    this.pending = new Map()
    this.activeTurns = new Map()
    this.serverRequests = new Map()
    this.parents = new Map()
    this.parentMetadata = new Set()
    this.owners = new Map()
    this.generation = randomUUID()
    this.authMode = undefined
    this.authRevision = 0
    this.sequence = 0
    this.process = null
    this.ready = null
  }

  connect() {
    if (!this.ready) {
      this.generation = randomUUID()
      this.authMode = undefined
      const child = spawn(this.executable, this.args, {
        env: { ...spawnEnvironment(), ...Object.fromEntries(['CODEX_HOME', 'SSH_AUTH_SOCK', 'HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY', 'SSL_CERT_FILE', 'SSL_CERT_DIR'].filter((key) => process.env[key]).map((key) => [key, process.env[key]])) },
        stdio: ['pipe', 'pipe', 'pipe']
      })
      this.process = child
      createInterface({ input: child.stdout }).on('line', (line) => {
        if (this.process === child) {
          Promise.resolve().then(() => this.receive(JSON.parse(line))).catch((error) => { this.emit('protocolError', error); this.disconnect(new Error('Codex sent an invalid protocol message'), child) })
        }
      })
      child.stderr.on('data', (data) => this.emit('diagnostic', data.toString()))
      child.stdin.on('error', (error) => { if (this.process === child) { this.disconnect(error, child) } })
      child.on('error', (error) => { if (this.process === child) { this.disconnect(error, child) } })
      child.on('exit', (code) => { if (this.process === child) { this.disconnect(new Error(`Codex app-server exited (${code})`), child) } })
      this.ready = this.send('initialize', {
        clientInfo: { name: 'remotecc_mobile', title: 'Remote agent mobile', version: '1.0.0' },
        capabilities: { experimentalApi: true }
      }).then((result) => {
        if (this.process !== child) { throw new Error('Codex connection changed during initialization') }
        child.stdin.write(`${JSON.stringify({ method: 'initialized', params: {} })}\n`)
        return result
      }).catch((error) => { this.disconnect(error, child); throw error })
    }
    return this.ready
  }

  async request(method, params = {}, timeout = this.timeout) {
    const ready = this.connect()
    const child = this.process
    await ready
    return this.send(method, params, child, timeout)
  }

  send(method, params, child = this.process, timeout = this.timeout) {
    if (['turn/start', 'review/start', 'turn/steer', 'thread/compact/start'].includes(method) && this.authMode !== undefined && this.authMode !== 'chatgpt') { return Promise.reject(new Error('Codex authentication changed. Sign in with a ChatGPT subscription before continuing.')) }
    if (!child || this.process !== child || child.stdin.destroyed) { return Promise.reject(new Error('Codex is disconnected')) }
    return new Promise((resolve, reject) => {
      const id = ++this.sequence
      const timer = timeout === null ? null : setTimeout(() => {
        this.pending.delete(id)
        reject(new Error(`Codex ${method} timed out`))
      }, timeout)
      this.pending.set(id, { resolve, reject, timer, method, params, authRevision: this.authRevision })
      try {
        child.stdin.write(`${JSON.stringify({ id, method, params })}\n`)
      } catch (error) {
        clearTimeout(timer)
        this.pending.delete(id)
        reject(error)
        this.disconnect(error, child)
      }
    })
  }

  receive(message) {
    if (message.method) {
      if (message.method === 'account/updated') { this.authMode = message.params?.authMode ?? null; this.authRevision += 1 }
      if (message.method === 'turn/started') {
        if (typeof message.params?.threadId === 'string' && typeof message.params.turn?.id === 'string') { this.activeTurns.set(message.params.threadId, message.params.turn.id) }
        for (const pending of this.pending.values()) {
          if (['turn/start', 'review/start', 'thread/shellCommand'].includes(pending.method) && pending.params.threadId === message.params?.threadId) { pending.turnId = message.params.turn?.id }
        }
      }
      if (message.method === 'turn/completed') {
        if (this.activeTurns.get(message.params?.threadId) === message.params?.turn?.id) { this.activeTurns.delete(message.params.threadId) }
        for (const [id, pending] of this.pending) {
          if (pending.turnId && pending.turnId === message.params?.turn?.id && pending.params.threadId === message.params.threadId) {
            this.pending.delete(id)
            clearTimeout(pending.timer)
            pending.resolve(pending.method === 'thread/shellCommand' ? {} : { turn: message.params.turn, ...(pending.method === 'review/start' ? { reviewThreadId: message.params.threadId } : {}) })
          }
        }
      }
      if (['thread/closed', 'thread/archived', 'thread/deleted'].includes(message.method)) {
        this.activeTurns.delete(message.params?.threadId)
        for (const [id, pending] of this.pending) {
          if (['turn/start', 'review/start', 'thread/shellCommand'].includes(pending.method) && pending.params.threadId === message.params?.threadId) {
            this.pending.delete(id)
            clearTimeout(pending.timer)
            pending.reject(new Error('Codex closed the task before acknowledging its turn. Refresh task history before continuing.'))
          }
        }
      }
      if (message.method === 'thread/started') { this.observeThread(message.params?.thread) }
      if (['item/started', 'item/completed'].includes(message.method)) { this.observeItem(message.params?.threadId, message.params?.item) }
      if (['turn/completed', 'thread/closed', 'thread/archived', 'thread/deleted'].includes(message.method)) {
        for (const request of this.requestsForThread(message.params?.threadId)) {
          this.serverRequests.delete(request.requestKey)
          this.emit('notification', { method: 'serverRequest/resolved', params: { threadId: request.params.threadId, requestId: request.id, requestKey: request.requestKey } })
        }
      }
      if (message.id !== undefined && typeof message.params?.threadId === 'string') {
        message = { ...message, requestKey: `${this.generation}:${JSON.stringify(message.id)}` }
        this.serverRequests.set(message.requestKey, message)
      }
      if (message.method === 'serverRequest/resolved') {
        const requestKey = `${this.generation}:${JSON.stringify(message.params?.requestId)}`
        if (this.serverRequests.get(requestKey)?.params.threadId === message.params?.threadId) {
          this.serverRequests.delete(requestKey)
          message = { ...message, params: { ...message.params, requestKey } }
        }
      }
      this.emit(message.id === undefined ? 'notification' : 'request', message)
    } else if (this.pending.has(message.id)) {
      const pending = this.pending.get(message.id)
      this.pending.delete(message.id)
      clearTimeout(pending.timer)
      if (message.error) {
        pending.reject(new Error(message.error.message || JSON.stringify(message.error)))
      } else {
        if (pending.method === 'account/read' && pending.authRevision === this.authRevision) { this.authMode = message.result?.account?.type === 'chatgpt' ? 'chatgpt' : message.result?.account?.type ?? null }
        if (['thread/read', 'thread/resume', 'thread/start', 'thread/fork'].includes(pending.method) && (['thread/start', 'thread/fork'].includes(pending.method) || message.result?.thread?.id === pending.params?.threadId)) { this.observeThread(message.result?.thread) }
        pending.resolve(message.result)
      }
    }
  }

  observeThread(thread) {
    this.linkParent(thread?.id, thread?.parentThreadId || thread?.source?.subAgent?.thread_spawn?.parent_thread_id, true)
    for (const turn of thread?.turns || []) {
      for (const item of turn.items || []) { this.observeItem(thread.id, item) }
    }
  }

  observeItem(threadId, item) {
    if (item?.type === 'subAgentActivity' && item.kind === 'started') { this.linkParent(item.agentThreadId, threadId) }
    if (item?.type === 'collabAgentToolCall' && item.tool === 'spawnAgent' && item.status === 'completed') {
      for (const child of item.receiverThreadIds || []) { this.linkParent(child, threadId) }
    }
  }

  linkParent(child, parent, authoritative = false) {
    if (typeof child === 'string' && typeof parent === 'string' && child !== parent && (authoritative || !this.parentMetadata.has(child))) {
      if (authoritative) { this.parentMetadata.add(child) }
      if (this.parents.get(child) === parent) { return }
      this.parents.set(child, parent)
      for (const request of this.serverRequests.values()) { this.emit('request', request) }
    }
  }

  registerOwner(threadId, sessionId) {
    this.owners.set(threadId, sessionId)
    for (const request of this.serverRequests.values()) { this.emit('request', request) }
  }

  unregisterOwner(threadId, sessionId) {
    if (this.owners.get(threadId) === sessionId) { this.owners.delete(threadId) }
  }

  ownerForThread(threadId) {
    const visited = new Set()
    while (threadId && !visited.has(threadId)) {
      if (this.owners.has(threadId)) { return { threadId, sessionId: this.owners.get(threadId) } }
      visited.add(threadId)
      threadId = this.parents.get(threadId)
    }
    return null
  }

  attentionForThread(threadId) {
    return [...this.serverRequests.values()].filter((request) => {
      const owner = this.ownerForThread(request.params.threadId)
      if (request.params.threadId === threadId || owner && owner.threadId !== threadId) { return false }
      const visited = new Set()
      let parent = this.parents.get(request.params.threadId)
      while (parent && !visited.has(parent)) {
        if (parent === threadId) { return true }
        visited.add(parent)
        parent = this.parents.get(parent)
      }
      return false
    })
  }

  requestsForThread(threadId) {
    return [...this.serverRequests.values()].filter((request) => request.params.threadId === threadId)
  }

  respond(id, result, threadId) {
    const request = this.serverRequests.get(id)
    if (this.authMode !== undefined && this.authMode !== 'chatgpt') { return false }
    if (!request || threadId !== undefined && request.params.threadId !== threadId || !this.process || this.process.stdin.destroyed) { return false }
    this.process.stdin.write(`${JSON.stringify({ id: request.id, result: request.method === 'item/permissions/requestApproval' && result.decision ? { permissions: ['accept', 'acceptForSession'].includes(result.decision) ? request.params.permissions : {}, scope: result.decision === 'acceptForSession' ? 'session' : 'turn' } : result })}\n`)
    this.serverRequests.delete(id)
    this.emit('notification', { method: 'serverRequest/resolved', params: { threadId: request.params.threadId, requestId: request.id, requestKey: request.requestKey } })
    return true
  }

  disconnect(error, child = this.process) {
    if (child !== this.process || !child) { return }
    this.process = null
    this.ready = null
    child.kill?.()
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer)
      pending.reject(error)
    }
    this.pending.clear()
    this.activeTurns.clear()
    this.serverRequests.clear()
    this.parents.clear()
    this.parentMetadata.clear()
    this.owners.clear()
    this.emit('disconnected', error)
  }

  close() {
    this.disconnect(new Error('Codex connection closed'))
  }
}

export const codexClient = new CodexClient()
