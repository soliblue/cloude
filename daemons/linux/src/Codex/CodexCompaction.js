import SubscriptionPolicy from '../Runtime/SubscriptionPolicy.js'
import { codexClient } from './CodexClient.js'
import { codexSessions } from './CodexSessions.js'
import { runnerManager } from '../RunnerManager.js'

export default class CodexCompaction {
  constructor(client, sessions, runners) {
    this.client = client
    this.sessions = sessions
    this.runners = runners
    this.states = new Map()
    client.on('notification', ({ method, params }) => {
      const entry = this.states.get(params?.threadId)
      if (entry && method === 'thread/tokenUsage/updated') {
        if (Number.isFinite(params.tokenUsage?.last?.totalTokens) && params.tokenUsage.last.totalTokens >= 0) { entry.state.contextTokens = params.tokenUsage.last.totalTokens; entry.state.usageAt = Date.now() }
        if (Number.isFinite(params.tokenUsage?.modelContextWindow) && params.tokenUsage.modelContextWindow > 0) { entry.state.contextWindow = params.tokenUsage.modelContextWindow }
      }
      if (entry?.started && ['pending', 'completed'].includes(entry.state.status)) {
        if (method === 'turn/started' && entry.state.status === 'pending') { entry.turnId = params.turn?.id }
        if (method === 'item/started' && params.item?.type === 'contextCompaction') { entry.turnId = params.turnId; entry.itemId = params.item.id }
        if (method === 'thread/compacted') {
          entry.state = { ...entry.state, status: 'completed', completedAt: Date.now() }
          entry.started = false
        }
        if (method === 'turn/completed' && entry.turnId && entry.turnId === params.turn?.id) {
          entry.state = { ...entry.state, completedAt: Date.now(), status: params.turn.status === 'completed' ? 'completed' : 'failed', threadId: params.threadId, ...(params.turn.status === 'completed' ? {} : { error: 'Context compaction stopped before completing. Retry when the task is idle.' }) }
          entry.started = false
        }
        if (method === 'error' && !params.willRetry && (!params.turnId || !entry.turnId || params.turnId === entry.turnId)) {
          this.failure(entry, 502, 'Codex could not compact this task. Check its subscription capacity and retry.')
        }
      }
    })
    client.on('disconnected', () => {
      for (const entry of this.states.values()) {
        if (entry.state.status === 'pending') { this.failure(entry, 502, 'Codex disconnected during compaction. Refresh task history before retrying.') }
      }
    })
  }

  busy(threadId) { return this.states.get(threadId)?.state.status === 'pending' }

  state(sessionId) {
    const threadId = this.sessions.read(sessionId)?.threadId
    return threadId ? { ...(this.states.get(threadId)?.state || { status: 'idle', threadId }) } : null
  }

  failure(entry, statusCode, error) {
    entry.state = { ...entry.state, status: 'failed', error }
    entry.started = false
    return { statusCode, state: entry.state }
  }

  async start(sessionId) {
    const session = this.sessions.read(sessionId)
    if (!session?.threadId || session.provider !== 'codex') { return { statusCode: 404, state: { error: 'Start or import a Codex task before compacting its context.' } } }
    const threadId = session.threadId
    if (this.runners.runners.has(sessionId.toLowerCase()) || [...this.runners.runners.values()].some((runner) => runner.threadId === threadId && !runner.hasExited)) {
      return { statusCode: 409, state: { error: 'Wait for the active turn to finish before compacting context.' } }
    }
    if (this.busy(threadId)) { return { statusCode: 202, state: this.state(sessionId) } }
    if (this.states.size >= 512) {
      const finished = [...this.states.entries()].find(([, entry]) => entry.state.status !== 'pending')
      if (finished) { this.states.delete(finished[0]) }
      else { return { statusCode: 503, state: { error: 'Too many compactions are pending. Wait for one to finish.' } } }
    }
    const entry = { state: { status: 'pending', threadId }, started: false }
    this.states.set(threadId, entry)
    return this.client.request('thread/read', { threadId, includeTurns: false }).then(async ({ thread }) => {
      if (entry.state.status !== 'pending') { return { statusCode: 502, state: entry.state } }
      if (thread?.status?.type === 'active') { return this.failure(entry, 409, 'Wait for the active turn to finish before compacting context.') }
      if (thread?.modelProvider !== 'openai' || typeof thread.cwd !== 'string' || !thread.cwd) { return this.failure(entry, 403, 'Compaction requires an existing task using the subscription-backed OpenAI provider.') }
      const policyError = await Promise.all([
        this.client.request('account/read', { refreshToken: false }),
        this.client.request('config/read', { cwd: thread.cwd, includeLayers: false }),
        this.client.request('account/rateLimits/read')
      ]).then((values) => Promise.resolve().then(() => SubscriptionPolicy.codex(...values)).then(() => null, (error) => error.message))
      if (policyError) { return this.failure(entry, 403, policyError) }
      if (entry.state.status !== 'pending') { return { statusCode: 502, state: entry.state } }
      const resumed = await this.client.request('thread/resume', { threadId, cwd: thread.cwd, modelProvider: 'openai' })
      if (resumed.modelProvider !== 'openai') { return this.failure(entry, 403, 'Codex did not select the subscription-backed OpenAI provider.') }
      if (resumed.thread?.status?.type === 'active') { return this.failure(entry, 409, 'The task became active before compaction. Retry after it finishes.') }
      if (entry.state.status !== 'pending') { return { statusCode: 502, state: entry.state } }
      entry.started = true
      await this.client.request('thread/compact/start', { threadId })
      return { statusCode: entry.state.status === 'pending' ? 202 : entry.state.status === 'completed' ? 200 : 502, state: entry.state }
    }).catch(() => this.failure(entry, 502, 'Codex could not start compaction. Check that the task is available and the host is connected.'))
  }
}

export const codexCompaction = new CodexCompaction(codexClient, codexSessions, runnerManager)
