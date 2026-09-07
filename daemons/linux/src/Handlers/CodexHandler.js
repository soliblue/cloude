import { randomUUID, createHash } from 'node:crypto'
import HTTPResponse from '../Networking/HTTPResponse.js'
import { codexCompaction } from '../Codex/CodexCompaction.js'
import CodexLogin from '../Codex/CodexLogin.js'
import { codexClient } from '../Codex/CodexClient.js'
import { codexSessions } from '../Codex/CodexSessions.js'
import { THREAD_SOURCE_KINDS } from '../Codex/CodexThreadSources.js'
import { runnerManager } from '../RunnerManager.js'

function validText(value, maximum = 512) {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= maximum && !/[\u0000-\u001f\u007f]/u.test(value)
}

function active(threadId, sessionId) {
  return runnerManager.runners.has(sessionId.toLowerCase()) || codexCompaction.busy(threadId) || [...runnerManager.runners.values()].some((runner) => runner.threadId === threadId)
}

export async function models() {
  return HTTPResponse.json(200, await codexClient.request('model/list', { includeHidden: false }))
}

export async function account() {
  return HTTPResponse.json(200, await codexClient.request('account/read', { refreshToken: false }))
}

export async function limits() {
  return HTTPResponse.json(200, await codexClient.request('account/rateLimits/read'))
}

export async function threads(request) {
  const query = request.query
  if (Object.keys(query).some((key) => !['cursor', 'limit', 'path', 'search', 'archived', 'refresh', 'sectionId', 'unsectioned'].includes(key))
    || ['archived', 'refresh', 'unsectioned'].some((key) => query[key] !== undefined && !['true', 'false'].includes(query[key]))
    || ['cursor', 'path', 'search', 'sectionId'].some((key) => query[key] !== undefined && (typeof query[key] !== 'string' || !query[key].trim() || query[key].length > (key === 'sectionId' ? 512 : 4096) || /[\u0000-\u001f\u007f]/u.test(query[key])))
    || query.sectionId !== undefined && query.unsectioned === 'true'
    || query.limit !== undefined && !/^(?:[1-9][0-9]?|100)$/u.test(query.limit)) {
    return HTTPResponse.json(400, { error: 'Provide valid thread filters, one section filter, and a page limit from 1 to 100.' })
  }
  return HTTPResponse.json(200, await codexClient.request('thread/list', {
    limit: Number(query.limit || 50), sortKey: query.sectionId ? 'section_position' : 'updated_at', sortDirection: query.sectionId ? 'asc' : 'desc', ...(query.sectionId ? { sectionId: query.sectionId, sourceKinds: THREAD_SOURCE_KINDS } : query.unsectioned === 'true' ? { sectionId: null, sourceKinds: THREAD_SOURCE_KINDS } : {}), useStateDbOnly: request.query.refresh !== 'true', ...(request.query.cursor ? { cursor: request.query.cursor } : {}),
    ...(request.query.path ? { cwd: request.query.path } : {}),
    ...(request.query.search ? { searchTerm: request.query.search } : {}),
    archived: request.query.archived === 'true'
  }))
}

export async function history(request, params) {
  const body = Buffer.from(JSON.stringify(await codexClient.request('thread/read', { threadId: codexSessions.read(params.id)?.threadId || params.id, includeTurns: true })))
  const etag = `"${createHash('sha256').update(body).digest('hex')}"`
  const unchanged = request.headers['if-none-match'] === etag
  return new HTTPResponse(unchanged ? 304 : 200, unchanged ? Buffer.alloc(0) : body, 'application/json', { ETag: etag, 'Cache-Control': 'private, no-cache' })
}

export async function fork(request, params) {
  const body = request.json()
  if (Object.keys(body).some((key) => !['newSessionId', 'path'].includes(key)) || body.newSessionId !== undefined && !validText(body.newSessionId) || body.path !== undefined && (!validText(body.path, 4096) || !body.path.startsWith('/'))) {
    return HTTPResponse.json(400, { error: 'Provide a valid new session ID and optional absolute path.' })
  }
  const sessionId = body.newSessionId || randomUUID()
  const source = codexSessions.read(params.id)
  const threadId = source?.threadId || params.id
  if (active(threadId, params.id) || runnerManager.runners.has(sessionId.toLowerCase()) || codexSessions.read(sessionId) || !codexSessions.reserve(sessionId)) {
    return HTTPResponse.json(409, { error: 'session_conflict' })
  }
  return Promise.resolve().then(async () => {
    const snapshot = await codexClient.request('thread/read', { threadId, includeTurns: false })
    if (snapshot.thread?.id !== threadId || snapshot.thread.status?.type === 'active' || active(threadId, params.id)) { return HTTPResponse.json(409, { error: 'The source task changed or is running. Wait before forking it.' }) }
    const result = await codexClient.request('thread/fork', { threadId, ...(body.path ? { cwd: body.path } : {}) })
    if (!validText(result.thread?.id) || result.thread.id === threadId || !validText(result.thread?.cwd, 4096)) { return HTTPResponse.json(502, { error: 'The host returned an invalid fork. Refresh the task list before retrying.' }) }
    codexSessions.write(sessionId, { threadId: result.thread.id, path: result.thread.cwd, provider: 'codex' })
    return HTTPResponse.json(200, { sessionId, threadId: result.thread.id, thread: result.thread })
  }).catch(() => HTTPResponse.json(502, { error: 'The host could not fork this task. Refresh its task list before retrying.' })).finally(() => codexSessions.release(sessionId))
}

export async function steer(request, params) {
  const body = request.json()
  if (typeof body?.prompt !== 'string' || !body.prompt.trim() || body.prompt.length > 32768 || body.requestId !== undefined && (typeof body.requestId !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/iu.test(body.requestId))) { return HTTPResponse.json(400, { error: 'Provide a nonempty steering message up to 32768 characters and an optional UUID requestId.' }) }
  return Promise.resolve().then(async () => {
    if (body.requestId && codexSessions.steeringReceipt(params.id, body.requestId, body.prompt)?.status === 'accepted') { return HTTPResponse.json(200, { ok: true }) }
    const runner = runnerManager.runners.get(params.id.toLowerCase())
    if (runner?.steer && runner.turnId) {
      await runner.steer(body.prompt, body.requestId)
      return HTTPResponse.json(200, { ok: true })
    }
    return HTTPResponse.json(409, { error: 'no_active_codex_turn' })
  }).catch(() => HTTPResponse.json(409, { error: 'Codex could not confirm this steering message. Check task history and the subscription account before sending another message.' }))
}

export function respond(request, params) {
  const body = request.json()
  const runner = runnerManager.runners.get(params.id.toLowerCase())
  if (body.requestId !== undefined && body.result && typeof body.result === 'object' && !Array.isArray(body.result) && (runner?.respond ? runner.respond(body.requestId, body.result) : codexClient.respond(body.requestId, body.result, codexSessions.read(params.id)?.threadId || params.id))) {
    return HTTPResponse.json(200, { ok: true })
  }
  return HTTPResponse.json(409, { error: 'request_not_pending' })
}

export async function archive(request, params) {
  const body = request.json()
  if (Object.keys(body).some((key) => key !== 'archived') || body.archived !== undefined && typeof body.archived !== 'boolean') { return HTTPResponse.json(400, { error: 'archived must be a boolean.' }) }
  const threadId = codexSessions.read(params.id)?.threadId || params.id
  if (active(threadId, params.id) || !codexSessions.reserve(params.id)) { return HTTPResponse.json(409, { error: 'Stop the active task before changing its archive state.' }) }
  return Promise.resolve().then(async () => {
    const snapshot = await codexClient.request('thread/read', { threadId, includeTurns: false })
    if (snapshot.thread?.id !== threadId || snapshot.thread.status?.type === 'active' || active(threadId, params.id)) { return HTTPResponse.json(409, { error: 'The task changed or is running. Refresh before changing its archive state.' }) }
    await codexClient.request(body.archived === false ? 'thread/unarchive' : 'thread/archive', { threadId })
    return HTTPResponse.json(200, { ok: true })
  }).catch(() => HTTPResponse.json(502, { error: 'The host could not update the archive state. Refresh the task list and retry.' })).finally(() => codexSessions.release(params.id))
}

export function requests(request, params) {
  const runner = runnerManager.runners.get(params.id.toLowerCase())
  const pending = new Map(codexClient.requestsForThread(codexSessions.read(params.id)?.threadId || runner?.threadId || params.id).map((request) => [request.requestKey || String(request.id), request]))
  for (const [id, request] of runner?.requests || []) { pending.set(id, request) }
  return HTTPResponse.json(200, { requests: [...pending.values()].map((request) => ({ requestId: request.requestKey || String(request.id), method: request.method, params: request.params })), agentAttention: codexClient.attentionForThread(codexSessions.read(params.id)?.threadId || runner?.threadId || params.id).map((request) => ({ threadId: request.params.threadId, requestId: request.requestKey })) })
}

export async function importThread(request, params) {
  const body = request.json()
  if (Object.keys(body).some((key) => !['threadId', 'path'].includes(key)) || !validText(body.threadId) || body.path !== undefined && !validText(body.path, 4096)) { return HTTPResponse.json(400, { error: 'Provide a valid native thread ID.' }) }
  if (runnerManager.runners.has(params.id.toLowerCase()) || !codexSessions.reserve(params.id)) { return HTTPResponse.json(409, { error: 'session_conflict' }) }
  return Promise.resolve().then(async () => {
    const result = await codexClient.request('thread/read', { threadId: body.threadId, includeTurns: true })
    if (result.thread?.id !== body.threadId || !validText(result.thread?.cwd, 4096)) { return HTTPResponse.json(502, { error: 'The host returned a different or invalid task. Refresh the task list.' }) }
    codexSessions.write(params.id, { threadId: result.thread.id, path: result.thread.cwd, provider: 'codex' })
    return HTTPResponse.json(200, { sessionId: params.id, threadId: result.thread.id, thread: result.thread })
  }).catch(() => HTTPResponse.json(502, { error: 'The host could not import this task. Refresh its task list and retry.' })).finally(() => codexSessions.release(params.id))
}

export async function rename(request, params) {
  const body = request.json()
  if (Object.keys(body).every((key) => key === 'name') && validText(body.name, 200)) {
    await codexClient.request('thread/name/set', { threadId: codexSessions.read(params.id)?.threadId || params.id, name: body.name.trim() })
    return HTTPResponse.json(200, { ok: true })
  }
  return HTTPResponse.json(400, { error: 'invalid_name' })
}

export async function skills(request) {
  return HTTPResponse.json(200, await codexClient.request('skills/list', { cwds: request.query.path ? [request.query.path] : [], forceReload: request.query.reload === 'true' }))
}

export async function modes() {
  return HTTPResponse.json(200, await codexClient.request('collaborationMode/list'))
}

export async function goal(request, params) {
  if (request.method === 'GET') {
    return HTTPResponse.json(200, await codexClient.request('thread/goal/get', { threadId: codexSessions.read(params.id)?.threadId || params.id }))
  }
  if (request.method === 'DELETE') {
    return HTTPResponse.json(200, await codexClient.request('thread/goal/clear', { threadId: codexSessions.read(params.id)?.threadId || params.id }))
  }
  const body = request.json()
  if ((body.objective === undefined || typeof body.objective === 'string' && body.objective.trim().length > 0 && body.objective.length <= 4000) && (body.tokenBudget === undefined || body.tokenBudget === null || Number.isSafeInteger(body.tokenBudget) && body.tokenBudget > 0) && (body.status === undefined || ['active', 'paused', 'blocked', 'usageLimited', 'budgetLimited', 'complete'].includes(body.status)) && (body.objective !== undefined || body.status !== undefined || body.tokenBudget !== undefined)) {
    return HTTPResponse.json(200, await codexClient.request('thread/goal/set', { threadId: codexSessions.read(params.id)?.threadId || params.id, ...(body.objective !== undefined ? { objective: body.objective.trim() } : {}), ...(body.status !== undefined ? { status: body.status } : {}), ...(body.tokenBudget !== undefined ? { tokenBudget: body.tokenBudget } : {}) }))
  }
  return HTTPResponse.json(400, { error: 'invalid_goal' })
}

export async function projects(request) {
  return HTTPResponse.json(200, await codexClient.request('project/list', { limit: 50, ...(request.query.cursor ? { cursor: request.query.cursor } : {}) }))
}

export async function createProject(request) {
  const body = request.json()
  if (typeof body.name === 'string' && body.name.trim().length > 0 && Array.isArray(body.roots) && body.roots.length > 0 && body.roots.every((root) => typeof root.path === 'string' && root.path.startsWith('/'))) {
    return HTTPResponse.json(200, await codexClient.request('project/create', { idempotencyKey: typeof body.idempotencyKey === 'string' ? body.idempotencyKey : randomUUID(), name: body.name.trim(), roots: body.roots.map((root) => ({ path: root.path })) }))
  }
  return HTTPResponse.json(400, { error: 'invalid_project' })
}

const codexLogin = new CodexLogin(codexClient)

export async function login(request) {
  if (request.method === 'POST') {
    const body = request.body.length ? request.json() : {}
    if (Object.keys(body).some((key) => key !== 'type') || body.type !== undefined && body.type !== 'chatgptDeviceCode') {
      return HTTPResponse.json(400, { error: 'Only ChatGPT device-code sign-in is supported.' })
    }
    const state = await codexLogin.start()
    return HTTPResponse.json(state.status === 'failed' ? 502 : 200, state)
  }
  if (request.method === 'DELETE') {
    const state = await codexLogin.cancel()
    return HTTPResponse.json(state.error && state.status === 'pending' ? 502 : 200, state)
  }
  return HTTPResponse.json(200, codexLogin.snapshot())
}


export async function compact(request, params) {
  if (request.method === 'POST') {
    const body = request.body.length ? request.json() : {}
    if (Object.keys(body).length) { return HTTPResponse.json(400, { error: 'Compaction accepts an empty request body only.' }) }
    const result = await codexCompaction.start(params.id)
    return HTTPResponse.json(result.statusCode, result.state)
  }
  const state = codexCompaction.state(params.id)
  return HTTPResponse.json(state ? 200 : 404, state || { error: 'No Codex task is mapped to this session.' })
}
