import fs from 'node:fs'
import { createHash } from 'node:crypto'
import { once } from 'node:events'
import { createInterface } from 'node:readline'
import Runner from '../Runner.js'
import { validReviewTarget } from './CodexReviewTarget.js'
import SubscriptionPolicy from '../Runtime/SubscriptionPolicy.js'
import { pushDelivery } from '../Notifications/PushDelivery.js'
import { codexClient } from './CodexClient.js'
import { codexSessions } from './CodexSessions.js'
import { normalizedMethods, normalizedNotification } from './CodexEvent.js'

export default class CodexRunner extends Runner {
  constructor(options, client = codexClient, sessions = codexSessions) {
    super(options)
    this.client = client
    this.sessions = sessions
    this.threadId = options.threadId || sessions.read(this.sessionId)?.threadId
    this.turnId = null
    this.reviewTarget = options.reviewTarget
    this.shellCommand = options.shellCommand
    this.reviewHash = createHash('sha256')
    this.reviewMessages = new Set()
    this.reviewStatusItems = new Set()
    this.skills = options.skills || []
    this.mentions = options.mentions || []
    this.projectId = options.projectId
    this.notificationContext = options.notificationContext
    this.requests = new Map()
    this.childRequests = new Map()
    this.journalFailed = false
    this.cancelled = false
    this.preflighting = false
    this.interruptedTurnId = null
    this.notification = (message) => this.receive(message)
    this.requested = (message) => {
      if (this.childRequests.has(message.requestKey) && this.client.ownerForThread?.(message.params?.threadId)?.sessionId !== this.sessionId) { this.clearChildAttention(message.requestKey) }
      if (!this.hasExited && message.params?.threadId !== this.threadId && this.client.ownerForThread?.(message.params?.threadId)?.sessionId === this.sessionId && !this.childRequests.has(message.requestKey)) {
        this.childRequests.set(message.requestKey, message.params.threadId)
        this.emit({ type: 'agent_attention', threadId: message.params.threadId, requestId: message.requestKey, pending: true })
        if (!this.hasExited) { this.notifyAttention(`attention-child:${createHash('sha256').update(message.requestKey).digest('hex')}`, { sessionId: this.sessionId, title: 'A helper needs your attention', body: 'Open the helper task to review its request and continue.', kind: 'attention' }) }
      }
      if (message.params?.threadId === this.threadId && !this.hasExited && !this.requests.has(message.requestKey || String(message.id))) {
        this.requests.set(message.requestKey || String(message.id), message)
        this.emit({ type: 'request', requestId: message.requestKey || String(message.id), method: message.method, params: message.params })
        this.notifyAttention(`attention:${this.sessionId}`, { sessionId: this.sessionId, title: message.method.includes('requestUserInput') ? 'Your agent has a question' : 'Approval needed', body: 'Open the task to continue your agent’s work.', kind: 'attention' })
      }
    }
    this.disconnected = (error) => this.fail(error)
    this.sessions.reset(this.sessionId)
    this.client.on('notification', this.notification)
    this.client.on('request', this.requested)
    this.client.on('disconnected', this.disconnected)
    this.heartbeat = setInterval(() => this.emit({ type: 'heartbeat' }), 20000)
    this.heartbeat.unref()
    if (this.threadId) { this.client.registerOwner?.(this.threadId, this.sessionId) }
  }

  notifyAttention(key, body) {
    pushDelivery.enqueue(key, 'POST', '/notifications', this.notificationContext ? { ...body, ...this.notificationContext, title: 'A scheduled agent needs attention', body: 'Open the scheduled run to review its request and continue.' } : body)
  }

  async subscribe(response, afterSeq = -1) {
    if (this.ring.length && afterSeq < this.ring[0].seq - 1) {
      const stream = fs.createReadStream(this.sessions.file(this.sessionId, 'jsonl'), { encoding: 'utf8' })
      const closed = new AbortController()
      response.once('close', () => { closed.abort(); stream.destroy() })
      for await (const line of createInterface({ input: stream, crlfDelay: Infinity })) {
        if (line && !response.destroyed) {
          const event = JSON.parse(line)
          if (event.seq > afterSeq) {
            if (response.write(`${line}\n`) === false) {
              await once(response, 'drain', { signal: closed.signal })
            }
            afterSeq = event.seq
          }
        }
      }
    }
    if (!response.destroyed) { super.subscribe(response, afterSeq) }
  }

  spawn(path, prompt, images = []) {
    this.begin(path, prompt, images).catch((error) => this.fail(error))
  }

  async begin(path, prompt, images) {
    this.path = path
    this.preflighting = true
    if (this.threadId && this.client.activeTurns?.has(this.threadId)) { throw new Error('This remote task is already running. Stop it or wait before sending another message.') }
    if (this.shellCommand !== undefined && (typeof this.shellCommand !== 'string' || !this.shellCommand.trim() || this.shellCommand.length > 16384 || this.reviewTarget !== undefined || images.length || this.skills.length || this.mentions.length)) { throw new Error('Invalid Codex shell command.') }
    if (this.reviewTarget !== undefined && !validReviewTarget(this.reviewTarget)) { throw new Error('Invalid Codex review target.') }
    SubscriptionPolicy.codex(...await Promise.all([this.client.request('account/read', { refreshToken: false }), this.client.request('config/read', { cwd: path, includeLayers: false }), this.shellCommand === undefined ? this.client.request('account/rateLimits/read') : {}]), { capacity: this.shellCommand === undefined })
    if (this.hasExited || this.cancelled) { this.finish(0); return }
    const options = {
      cwd: path,
      modelProvider: 'openai',
      ...(this.model ? { model: this.model } : {}),
      approvalPolicy: this.permissionMode === 'bypassPermissions' ? 'never' : 'on-request',
      sandbox: this.permissionMode === 'plan' ? 'read-only' : this.permissionMode === 'bypassPermissions' ? 'danger-full-access' : 'workspace-write'
    }
    if (this.threadId && this.client.activeTurns?.has(this.threadId)) { throw new Error('This remote task is already running. Stop it or wait before sending another message.') }
    const result = await this.client.request(this.threadId ? 'thread/resume' : 'thread/start', {
      ...options,
      ...(this.threadId ? { threadId: this.threadId } : this.projectId ? { projectId: this.projectId } : {})
    })
    if (this.hasExited) { return }
    if (result.thread?.status?.type === 'active' || this.client.activeTurns?.has(result.thread?.id)) { throw new Error('This remote task is already running. Stop it or wait before sending another message.') }
    if (result.modelProvider !== 'openai') {
      throw new Error('Codex did not select the subscription-backed OpenAI provider.')
    }
    this.threadId = result.thread.id
    this.client.registerOwner?.(this.threadId, this.sessionId)
    this.sessions.write(this.sessionId, { threadId: this.threadId, path, provider: 'codex' })
    this.emit({ type: 'session', provider: 'codex', threadId: this.threadId })
    if (this.shellCommand === undefined) { this.emit({ event: { type: 'system', subtype: 'init', model: this.reviewTarget ? result.model : this.model || result.model } }) }
    if (this.cancelled) {
      this.finish(0)
    } else {
      SubscriptionPolicy.codex(await this.client.request('account/read', { refreshToken: false }), { config: {} }, {}, { capacity: false })
      if (this.hasExited || this.cancelled) { this.finish(0); return }
      if (this.client.activeTurns?.has(this.threadId)) { throw new Error('This remote task is already running. Stop it or wait before sending another message.') }
      this.preflighting = false
      const turn = await this.client.request(this.shellCommand !== undefined ? 'thread/shellCommand' : this.reviewTarget ? 'review/start' : 'turn/start', this.shellCommand !== undefined ? { threadId: this.threadId, command: this.shellCommand } : this.reviewTarget ? { threadId: this.threadId, delivery: 'inline', target: this.reviewTarget } : {
        threadId: this.threadId,
        collaborationMode: { mode: this.permissionMode === 'plan' ? 'plan' : 'default', settings: { model: this.model || result.model, reasoning_effort: this.effort ?? result.reasoningEffort ?? null, developer_instructions: null } },
        input: [{ type: 'text', text: prompt }, ...this.skills.filter((skill) => typeof skill?.name === 'string' && typeof skill.path === 'string').map((skill) => ({ type: 'skill', name: skill.name, path: skill.path })), ...this.mentions.filter((mention) => typeof mention?.name === 'string' && typeof mention.path === 'string').map((mention) => ({ type: 'mention', name: mention.name, path: mention.path })), ...images.filter((image) => typeof image?.data === 'string').map((image) => ({ type: 'image', url: `data:${image.mediaType || 'image/png'};base64,${image.data}` }))],
        ...(this.model ? { model: this.model } : {}),
        ...(this.effort ? { effort: this.effort } : {})
      }, null)
      if (this.hasExited) { return }
      if (this.reviewTarget && turn.reviewThreadId !== this.threadId) { throw new Error('Codex returned an unexpected review thread.') }
      if (this.shellCommand === undefined) { this.turnId = turn.turn.id }
      if (this.shellCommand === undefined && this.cancelled && !this.hasExited) {
        this.abort()
      }
    }
  }

  receive({ method, params }) {
    if (method === 'account/updated' && params?.authMode !== 'chatgpt' && !this.hasExited && this.shellCommand === undefined) {
      this.emit({ type: 'error', message: 'Codex authentication changed. This turn is stopping; sign in with a ChatGPT subscription before continuing.' })
      this.abort()
    }
    if (method === 'serverRequest/resolved' && this.childRequests.has(params?.requestKey)) { this.clearChildAttention(params.requestKey) }
    if (params?.threadId === this.threadId && !this.hasExited && (!this.preflighting || ['thread/closed', 'thread/archived', 'thread/deleted', 'serverRequest/resolved'].includes(method))) {
      if (method === 'turn/started') {
        this.turnId = params.turn.id
        if (this.cancelled) { this.abort() }
      }
      if (method === 'serverRequest/resolved' && this.requests.delete(params.requestKey || String(params.requestId))) {
        if (!this.requests.size) { pushDelivery.cancel(`attention:${this.sessionId}`) }
        this.emit({ type: 'request_resolved', requestId: params.requestKey || String(params.requestId) })
      }
      if (!normalizedMethods.has(method)) { this.emit({ codex: { method, params } }) }
      if (['thread/closed', 'thread/archived', 'thread/deleted'].includes(method)) {
        this.fail(new Error('The task was closed on the host. Refresh its history before continuing.'))
        return
      }
      if (method === 'item/commandExecution/outputDelta' || method === 'item/fileChange/outputDelta') {
        this.emit({ type: 'tool_output_delta', toolUseId: params.itemId, text: params.delta || '' })
      }
      if (method === 'item/mcpToolCall/progress') {
        this.emit({ type: 'tool_output_delta', toolUseId: params.itemId, text: `${params.message || ''}\n` })
      }
      if (method === 'thread/tokenUsage/updated') {
        this.emit({ type: 'usage', contextTokens: params.tokenUsage?.last?.totalTokens, contextWindow: params.tokenUsage?.modelContextWindow, inputTokens: params.tokenUsage?.total?.inputTokens, outputTokens: params.tokenUsage?.total?.outputTokens })
      }
      if (this.reviewTarget && method === 'item/agentMessage/delta') { this.reviewHash.update(params.delta || '') }
      const reviewItem = params.item
      if ((method === 'item/started' || method === 'item/completed') && reviewItem?.type === 'enteredReviewMode' && !this.reviewStatusItems.has(reviewItem.id)) {
        this.reviewStatusItems.add(reviewItem.id)
        this.emit({ type: 'status', state: 'reviewing', message: 'Reviewing changes'  })
      }
      if (method === 'item/completed' && reviewItem?.type === 'exitedReviewMode') { this.emit({ type: 'status', state: 'review_complete', message: 'Review completed'  }) }
      const reviewDigest = this.reviewTarget && ['exitedReviewMode', 'agentMessage'].includes(reviewItem?.type) ? createHash('sha256').update(reviewItem.review || reviewItem.text || '').digest('hex') : null
      const duplicateReview = reviewDigest && method === 'item/completed' && (this.reviewMessages.has(reviewDigest) || reviewItem.type === 'exitedReviewMode' && this.reviewHash.copy().digest('hex') === reviewDigest)
      if (reviewDigest && method === 'item/completed' && this.reviewMessages.size < 256) { this.reviewMessages.add(reviewDigest) }
      if (!duplicateReview) {
        for (const event of normalizedNotification(method, params)) {
          this.emit({ event })
        }
      }
      if (method === 'thread/compacted' || method === 'item/started' && params.item?.type === 'contextCompaction') {
        this.emit({ type: 'status', state: 'compacting' })
      }
      if (method === 'turn/completed') {
        if (params.turn.status === 'failed') {
          this.emit({ type: 'error', message: params.turn.error?.message || 'Codex turn failed' })
        }
        if (params.turn.status === 'interrupted') {
          this.emit({ type: 'aborted' })
        }
        this.emit({ event: { type: 'result', subtype: params.turn.status, is_error: params.turn.status === 'failed' } })
        this.finish(params.turn.status === 'failed' ? 1 : 0)
      }
      if (method === 'error' && !params.willRetry) {
        this.emit({ type: 'error', message: params.error?.message || 'Codex error' })
      }
    }
  }

  clearChildAttention(requestId) {
    const threadId = this.childRequests.get(requestId)
    if (threadId) {
      this.childRequests.delete(requestId)
      pushDelivery.cancel(`attention-child:${createHash('sha256').update(requestId).digest('hex')}`)
      this.emit({ type: 'agent_attention', threadId, requestId, pending: false })
    }
  }

  record(data) {
    if (!this.journalFailed) {
      try {
        this.sessions.append(this.sessionId, data)
      } catch {
        this.journalFailed = true
        this.cancelled = true
        if (this.turnId && !this.hasExited) { this.client.request('turn/interrupt', { threadId: this.threadId, turnId: this.turnId }).catch(() => {}) }
        this.fail(new Error('The daemon could not save streamed output. Check host storage and task status before continuing.'))
        return false
      }
    }
    return true
  }

  abort() {
    this.cancelled = true
    if (this.turnId && !this.hasExited && this.interruptedTurnId !== this.turnId) {
      this.interruptedTurnId = this.turnId
      this.client.request('turn/interrupt', { threadId: this.threadId, turnId: this.turnId }).catch((error) => this.fail(error))
    }
  }

  async steer(prompt, requestId) {
    const turnId = this.turnId
    SubscriptionPolicy.codex(...await Promise.all([this.client.request('account/read', { refreshToken: false }), this.client.request('config/read', { cwd: this.path, includeLayers: false }), this.client.request('account/rateLimits/read')]))
    if (this.hasExited || this.cancelled || !turnId || this.turnId !== turnId) { throw new Error('The active Codex turn changed. Refresh the task before steering.') }
    const perform = () => {
      if (this.hasExited || this.cancelled || this.turnId !== turnId) { throw new Error('The active Codex turn changed. Refresh the task before steering.') }
      return this.client.request('turn/steer', { threadId: this.threadId, expectedTurnId: turnId, input: [{ type: 'text', text: prompt }] })
    }
    return requestId ? this.sessions.steer(this.sessionId, requestId, prompt, perform) : perform()
  }

  respond(requestId, result) {
    const request = this.requests.get(String(requestId))
    if (request) {
      const accepted = this.client.respond(request.requestKey || request.id, request.method === 'item/permissions/requestApproval' && result.decision ? { permissions: result.decision === 'accept' || result.decision === 'acceptForSession' ? request.params.permissions : {}, scope: result.decision === 'acceptForSession' ? 'session' : 'turn' } : result, this.threadId)
      if (accepted === false) { return false }
      const pending = this.requests.delete(String(requestId))
      if (this.requests.size === 0) { pushDelivery.cancel(`attention:${this.sessionId}`) }
      if (pending) { this.emit({ type: 'request_resolved', requestId: String(requestId) }) }
      return true
    }
    return false
  }

  fail(error) {
    if (!this.hasExited) {
      this.lastError = error.message
      this.emit({ type: 'error', message: error.message })
      this.finish(1)
    }
  }

  finish(code) {
    for (const requestId of [...this.childRequests.keys()]) { this.clearChildAttention(requestId) }
    this.client.unregisterOwner?.(this.threadId, this.sessionId)
    clearInterval(this.heartbeat)
    pushDelivery.cancel(`attention:${this.sessionId}`)
    this.client.off('notification', this.notification)
    this.client.off('request', this.requested)
    this.client.off('disconnected', this.disconnected)
    this.requests.clear()
    super.finish(code)
  }
}
