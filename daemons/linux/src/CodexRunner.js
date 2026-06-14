import { spawn } from 'node:child_process'
import { StringDecoder } from 'node:string_decoder'
import { codexThreadStore } from './CodexThreadStore.js'
import { codexCommand, spawnEnvironment } from './Runtime/CodexRuntime.js'

export default class CodexRunner {
  constructor({ sessionId, hasStartedBefore, model, effort, permissionMode, onFinish }) {
    this.sessionId = sessionId
    this.hasExited = false
    this.hasStartedBefore = hasStartedBefore
    this.model = model
    this.effort = effort
    this.permissionMode = permissionMode
    this.onFinish = onFinish
    this.process = null
    this.ring = []
    this.subscribers = new Set()
    this.seq = 0
    this.lineBuffer = ''
    this.decoder = new StringDecoder('utf8')
    this.nextRequestId = 1
    this.pending = new Map()
    this.activeThreadId = null
    this.activeTurnId = null
    this.agentTextByItem = new Map()
    this.outputByItem = new Map()
    this.contextTokens = null
    this.contextWindow = null
  }

  spawn(path, prompt, imagePaths) {
    const { executable, leadingArguments } = codexCommand()
    this.process = spawn(executable, [...leadingArguments, 'app-server', '--listen', 'stdio://'], {
      cwd: path,
      env: spawnEnvironment(),
      stdio: ['pipe', 'pipe', 'pipe']
    })
    this.process.stdout.on('data', (data) => {
      this.ingest(this.decoder.write(data))
    })
    this.process.stderr.on('data', (data) => {
      console.error(`CodexRunner[${this.sessionId}]: ${data}`)
    })
    this.process.on('error', () => {
      this.emit({ type: 'error', message: 'spawn_failed: codex app-server' })
      this.finish(-1, false)
    })
    this.process.on('close', (code) => {
      this.finish(typeof code === 'number' ? code : -1, false)
    })
    this.initialize(path, prompt, imagePaths)
  }

  subscribe(response, afterSeq = -1) {
    response.on('close', () => {
      this.subscribers.delete(response)
    })
    response.on('error', () => {
      this.subscribers.delete(response)
    })
    for (const entry of this.ring) {
      if (entry.seq > afterSeq) {
        response.write(entry.data)
      }
    }
    if (this.hasExited) {
      response.end()
      return
    }
    this.subscribers.add(response)
  }

  abort() {
    if (this.activeThreadId && this.activeTurnId) {
      this.emit({ type: 'aborted' })
      this.request('turn/interrupt', { threadId: this.activeThreadId, turnId: this.activeTurnId }, () => {})
    }
    setTimeout(() => {
      if (!this.hasExited) {
        this.finish(130)
      }
    }, 5000).unref()
  }

  initialize(path, prompt, imagePaths) {
    this.request('initialize', {
      clientInfo: { name: 'remote_cc', title: 'Remote CC', version: '1.0.0' },
      capabilities: { experimentalApi: true }
    }, () => {})
    this.notify('initialized', {})
    const threadId = this.hasStartedBefore ? codexThreadStore.threadId(this.sessionId) : null
    if (threadId) {
      this.resume(threadId, path, prompt, imagePaths)
    } else {
      this.startThread(path, prompt, imagePaths)
    }
  }

  startThread(path, prompt, imagePaths) {
    this.request('thread/start', { ...this.baseThreadParams(path), serviceName: 'remote_cc' }, (result) => {
      this.threadReady(result, path, prompt, imagePaths)
    })
  }

  resume(threadId, path, prompt, imagePaths) {
    this.request('thread/resume', {
      ...this.baseThreadParams(path),
      threadId,
      excludeTurns: true
    }, (result) => {
      this.threadReady(result, path, prompt, imagePaths)
    })
  }

  threadReady(result, path, prompt, imagePaths) {
    const threadId = result.thread?.id
    if (threadId) {
      this.activeThreadId = threadId
      codexThreadStore.set(threadId, this.sessionId)
      this.emit({ event: { type: 'system', subtype: 'init', session_id: threadId } })
      this.startTurn(threadId, path, prompt, imagePaths)
    } else {
      this.emit({ type: 'error', message: 'codex_thread_missing' })
      this.finish(-1)
    }
  }

  startTurn(threadId, path, prompt, imagePaths) {
    const params = {
      threadId,
      input: [{ type: 'text', text: prompt, text_elements: [] }, ...imagePaths.map((file) => ({ type: 'localImage', path: file }))],
      cwd: path
    }
    if (this.model) {
      params.model = this.model
    }
    if (this.resolvedEffort()) {
      params.effort = this.resolvedEffort()
    }
    this.request('turn/start', params, (result) => {
      this.activeTurnId = result.turn?.id || null
    })
  }

  baseThreadParams(path) {
    const params = {
      cwd: path,
      approvalPolicy: this.permissionMode === 'bypassPermissions' ? 'never' : 'on-request',
      sandbox: this.sandboxMode(),
      experimentalRawEvents: false,
      persistExtendedHistory: false
    }
    if (this.model) {
      params.model = this.model
    }
    if (this.resolvedEffort()) {
      params.effort = this.resolvedEffort()
    }
    return params
  }

  resolvedEffort() {
    return this.effort === 'max' ? 'xhigh' : this.effort
  }

  sandboxMode() {
    if (this.permissionMode === 'plan') {
      return 'read-only'
    }
    return this.permissionMode === 'bypassPermissions' ? 'danger-full-access' : 'workspace-write'
  }

  request(method, params, onResult) {
    const id = this.nextRequestId
    this.nextRequestId += 1
    this.pending.set(id, onResult)
    this.send({ id, method, params })
  }

  notify(method, params) {
    this.send({ method, params })
  }

  send(object) {
    this.process.stdin.write(`${JSON.stringify(object)}\n`)
  }

  ingest(chunk) {
    this.lineBuffer += chunk
    let newline = this.lineBuffer.indexOf('\n')
    while (newline !== -1) {
      const line = this.lineBuffer.slice(0, newline)
      this.lineBuffer = this.lineBuffer.slice(newline + 1)
      if (line.length !== 0) {
        this.handle(JSON.parse(line))
      }
      newline = this.lineBuffer.indexOf('\n')
    }
  }

  handle(message) {
    if (message.method) {
      if (message.id !== undefined) {
        this.handleServerRequest(message.id, message.method, message.params || {})
      } else {
        this.handleNotification(message.method, message.params || {})
      }
    } else if (message.id !== undefined) {
      const callback = this.pending.get(message.id)
      this.pending.delete(message.id)
      if (message.error) {
        this.emit({ type: 'error', message: message.error.message || 'codex_error' })
      } else {
        callback?.(message.result || {})
      }
    }
  }

  handleServerRequest(id, method, params) {
    if (method === 'item/commandExecution/requestApproval') {
      this.send({ id, result: { decision: this.permissionMode === 'plan' ? 'decline' : 'accept' } })
    } else if (method === 'item/fileChange/requestApproval') {
      this.send({ id, result: { decision: this.permissionMode === 'plan' ? 'decline' : 'accept' } })
    } else if (method === 'item/tool/requestUserInput') {
      this.send({ id, result: { answers: {} } })
    } else if (method === 'item/tool/call') {
      this.send({ id, result: { contentItems: [], success: false } })
    } else {
      this.send({ id, error: { code: -32601, message: 'unsupported_request' } })
    }
    if (params.itemId) {
      this.outputByItem.set(params.itemId, method)
    }
  }

  handleNotification(method, params) {
    if (method === 'item/agentMessage/delta' && params.itemId && typeof params.delta === 'string') {
      this.agentTextByItem.set(params.itemId, `${this.agentTextByItem.get(params.itemId) || ''}${params.delta}`)
      this.emitTextDelta(params.delta)
    } else if ((method === 'item/reasoning/textDelta' || method === 'item/reasoning/summaryTextDelta') && typeof params.delta === 'string') {
      this.emitThinkingDelta(params.delta)
    } else if ((method === 'item/commandExecution/outputDelta' || method === 'item/fileChange/outputDelta') && params.itemId && typeof params.delta === 'string') {
      this.outputByItem.set(params.itemId, `${this.outputByItem.get(params.itemId) || ''}${params.delta}`)
    } else if (method === 'thread/tokenUsage/updated') {
      this.updateUsage(params)
    } else if (method === 'item/started') {
      this.handleStarted(params)
    } else if (method === 'item/completed') {
      this.handleCompleted(params)
    } else if (method === 'thread/compacted') {
      this.emit({ type: 'status', state: 'compacting' })
    } else if (method === 'turn/completed') {
      this.handleTurnCompleted(params)
    } else if (method === 'error') {
      this.emit({ type: 'error', message: params.message || 'codex_error' })
    }
  }

  handleStarted(params) {
    const item = params.item || {}
    if (item.type === 'contextCompaction') {
      this.emit({ type: 'status', state: 'compacting' })
    } else {
      const use = this.toolUse(item)
      if (use) {
        this.emitAssistant('', [use])
      }
    }
  }

  handleCompleted(params) {
    const item = params.item || {}
    if (item.type === 'agentMessage') {
      this.emitAssistant(item.text || this.agentTextByItem.get(item.id) || '')
      this.agentTextByItem.delete(item.id)
    } else if (['commandExecution', 'fileChange', 'mcpToolCall', 'dynamicToolCall', 'webSearch'].includes(item.type)) {
      this.emitToolResult(item)
    }
  }

  handleTurnCompleted(params) {
    const status = params.turn?.status
    if (status === 'failed') {
      this.emit({ type: 'error', message: params.turn?.error?.message || 'codex_turn_failed' })
    } else {
      if (status === 'interrupted') {
        this.emit({ type: 'aborted' })
      }
      this.emitResult()
    }
    this.finish(0)
  }

  updateUsage(params) {
    this.contextTokens = params.tokenUsage?.total?.totalTokens || this.contextTokens
    this.contextWindow = params.tokenUsage?.modelContextWindow || this.contextWindow
  }

  toolUse(item) {
    if (!item.id) {
      return null
    }
    if (item.type === 'commandExecution') {
      return { id: item.id, name: 'Bash', input: { command: item.command || '' } }
    }
    if (item.type === 'fileChange') {
      return { id: item.id, name: 'Edit', input: { file_path: this.fileChangeSummary(item.changes || []) } }
    }
    if (item.type === 'mcpToolCall') {
      return { id: item.id, name: item.tool || 'MCP', input: item.arguments || {} }
    }
    if (item.type === 'dynamicToolCall') {
      return { id: item.id, name: item.tool || 'Tool', input: item.arguments || {} }
    }
    if (item.type === 'webSearch') {
      return { id: item.id, name: 'WebSearch', input: { query: item.query || '' } }
    }
    return null
  }

  emitToolResult(item) {
    const failed = item.status === 'failed' || item.status === 'declined'
    const text = this.outputByItem.get(item.id) || this.completedText(item)
    this.emit({
      event: {
        type: 'user',
        message: {
          content: [{ type: 'tool_result', tool_use_id: item.id, content: text, is_error: failed }]
        }
      }
    })
    this.outputByItem.delete(item.id)
  }

  completedText(item) {
    if (item.type === 'commandExecution') {
      return item.aggregatedOutput || ''
    }
    if (item.type === 'fileChange') {
      return this.fileChangeSummary(item.changes || [])
    }
    if (item.type === 'mcpToolCall') {
      return item.error?.message || JSON.stringify(item.result || '')
    }
    if (item.type === 'dynamicToolCall') {
      return JSON.stringify(item.contentItems || '')
    }
    return item.query || ''
  }

  fileChangeSummary(changes) {
    return changes.map((change) => change.path).filter(Boolean).join('\n')
  }

  emitTextDelta(text) {
    this.emit({
      event: {
        type: 'stream_event',
        event: { type: 'content_block_delta', delta: { type: 'text_delta', text } }
      }
    })
  }

  emitThinkingDelta(text) {
    this.emit({
      event: {
        type: 'stream_event',
        event: { type: 'content_block_delta', delta: { type: 'thinking_delta', thinking: text } }
      }
    })
  }

  emitAssistant(text = '', toolUses = []) {
    const content = [
      ...(text.length > 0 ? [{ type: 'text', text }] : []),
      ...toolUses.map((use) => ({ type: 'tool_use', id: use.id, name: use.name, input: use.input }))
    ]
    if (content.length > 0) {
      const message = { model: this.model || 'gpt-5.5', content }
      if (this.contextTokens) {
        message.usage = { input_tokens: this.contextTokens }
      }
      this.emit({ event: { type: 'assistant', message } })
    }
  }

  emitResult() {
    const event = { type: 'result' }
    if (this.contextWindow) {
      event.modelUsage = { codex: { contextWindow: this.contextWindow } }
    }
    this.emit({ event })
  }

  emit(partial) {
    this.seq += 1
    const data = Buffer.from(`${JSON.stringify({ ...partial, seq: this.seq, sessionId: this.sessionId })}\n`)
    this.ring.push({ seq: this.seq, data })
    if (this.ring.length > 1000) {
      this.ring.splice(0, this.ring.length - 1000)
    }
    for (const subscriber of this.subscribers) {
      subscriber.write(data)
      if (subscriber.writableLength > 8 * 1024 * 1024) {
        subscriber.destroy()
      }
    }
  }

  finish(exitCode, terminateProcess = true) {
    if (this.hasExited) {
      return
    }
    this.hasExited = true
    if (terminateProcess && this.process?.exitCode === null) {
      this.process.kill('SIGTERM')
    }
    this.emit({ type: 'exit', code: exitCode })
    for (const subscriber of this.subscribers) {
      subscriber.end()
    }
    this.subscribers.clear()
    this.onFinish?.()
  }
}
