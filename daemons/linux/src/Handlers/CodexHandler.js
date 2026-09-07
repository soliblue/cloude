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
    || ['cursor', 'path', 'search', 'sectionId'].some((key) => query[key] !== undefined && (typeof query[key] !== 'string' || key !== 'search' && !query[key].trim() || query[key].length > (key === 'sectionId' ? 512 : 4096) || /[\u0000-\u001f\u007f]/u.test(query[key])))
    || query.sectionId !== undefined && query.unsectioned === 'true'
    || query.limit !== undefined && !/^(?:[1-9][0-9]?|100)$/u.test(query.limit)) {
    return HTTPResponse.json(400, { error: 'Provide valid thread filters, one section filter, and a page limit from 1 to 100.' })
  }
  return HTTPResponse.json(200, await codexClient.request('thread/list', {
    limit: Number(query.limit || 50), sortKey: query.sectionId ? 'section_position' : 'updated_at', sortDirection: query.sectionId ? 'asc' : 'desc', ...(query.sectionId ? { sectionId: query.sectionId, sourceKinds: THREAD_SOURCE_KINDS } : query.unsectioned === 'true' ? { sectionId: null, sourceKinds: THREAD_SOURCE_KINDS } : {}), useStateDbOnly: request.query.refresh !== 'true', ...(request.query.cursor ? { cursor: request.query.cursor } : {}),
    ...(request.query.path ? { cwd: request.query.path } : {}),
    ...(request.query.search?.trim() ? { searchTerm: request.query.search.trim() } : {}),
    archived: request.query.archived === 'true'
  }))
}

export async function history(request, params) {
  const query = request.query || {}
  if (!validText(params.id) || Object.keys(query).some(key => key !== 'includeTurns') || query.includeTurns !== undefined && !['true', 'false'].includes(query.includeTurns)) { return HTTPResponse.json(400, { error: 'includeTurns must be true or false.' }) }
  const threadId = codexSessions.read(params.id)?.threadId || params.id
  return codexClient.request('thread/read', { threadId, includeTurns: query.includeTurns !== 'false' }).then(result => {
    if ((codexSessions.read(params.id)?.threadId || params.id) !== threadId) { return HTTPResponse.json(409, { error: 'The task changed while loading history. Refresh and retry.' }) }
    if (result.thread?.id !== threadId) { return HTTPResponse.json(502, { error: 'The host returned history for a different task. Refresh and retry.' }) }
    const body = Buffer.from(JSON.stringify(result))
    const etag = `"${createHash('sha256').update(body).digest('hex')}"`
    const unchanged = request.headers['if-none-match'] === etag
    return new HTTPResponse(unchanged ? 304 : 200, unchanged ? Buffer.alloc(0) : body, 'application/json', { ETag: etag, 'Cache-Control': 'private, no-cache' })
  }).catch(() => HTTPResponse.json(502, { error: 'The host could not read this task. Refresh its task list and retry.' }))
}

export async function turns(request, params) {
  const query = request.query || {}
  if (!validText(params.id) || Object.keys(query).some(key => !['cursor', 'limit', 'sortDirection'].includes(key))
    || query.cursor !== undefined && !validText(query.cursor, 4096)
    || query.limit !== undefined && !/^(?:[1-9]|[1-4][0-9]|50)$/u.test(query.limit)
    || query.sortDirection !== undefined && !['asc', 'desc'].includes(query.sortDirection)) { return HTTPResponse.json(400, { error: 'Provide a valid cursor, a limit from 1 to 50, and asc or desc ordering.' }) }
  const threadId = codexSessions.read(params.id)?.threadId || params.id
  const limit = Number(query.limit || 25)
  return codexClient.request('thread/turns/list', { threadId, limit, sortDirection: query.sortDirection || 'desc', itemsView: 'full', ...(query.cursor !== undefined ? { cursor: query.cursor } : {}) }).then(result => {
    if ((codexSessions.read(params.id)?.threadId || params.id) !== threadId) { return HTTPResponse.json(409, { error: 'The task changed while loading history. Refresh and retry.' }) }
    if (!Array.isArray(result.data) || result.data.length > limit
      || result.data.some(turn => !validText(turn?.id) || !Array.isArray(turn.items) || turn.itemsView !== undefined && turn.itemsView !== 'full' || !['completed', 'interrupted', 'failed', 'inProgress'].includes(turn.status))
      || new Set(result.data.map(turn => turn.id)).size !== result.data.length
      || ['nextCursor', 'backwardsCursor'].some(key => result[key] != null && !validText(result[key], 4096))) { return HTTPResponse.json(502, { error: 'The host returned incomplete history. Update the host daemon or retry.' }) }
    return HTTPResponse.json(200, { threadId, data: result.data, nextCursor: result.nextCursor ?? null, backwardsCursor: result.backwardsCursor ?? null })
  }).catch(() => HTTPResponse.json(502, { error: 'The host could not page this task. Check its Codex version and retry.' }))
}

export async function fork(request, params) {
  const body = request.json()
  if (Object.keys(body).some((key) => !['newSessionId', 'path'].includes(key)) || body.newSessionId !== undefined && !validText(body.newSessionId) || body.path !== undefined && (!validText(body.path, 4096) || !body.path.startsWith('/'))) {
    return HTTPResponse.json(400, { error: 'Provide a valid new session ID and optional absolute path.' })
  }
  const sessionId = body.newSessionId || randomUUID()
  const source = codexSessions.read(params.id)
  const threadId = source?.threadId || params.id
  const key = sessionId.toLowerCase()
  const fingerprint = createHash('sha256').update(JSON.stringify([params.id.toLowerCase(), threadId, body.path ?? null])).digest('hex')
  let receipt
  try {
    receipt = codexSessions.forkReceipt(sessionId, fingerprint)
  } catch {
    return HTTPResponse.json(409, { code: 'fork_conflict', error: 'This side-chat attempt belongs to a different source or directory, or its saved record is invalid.', retriable: false })
  }
  if (codexSessions.forks.has(key)) {
    return HTTPResponse.json(409, { code: codexSessions.forks.get(key) === fingerprint ? 'fork_pending' : 'fork_conflict', error: codexSessions.forks.get(key) === fingerprint ? 'This side chat is still being created. Retry the same attempt shortly.' : 'This side-chat attempt belongs to a different source or directory.', retriable: codexSessions.forks.get(key) === fingerprint })
  }
  if (receipt?.status === 'completed') {
    if (!codexSessions.reserve(sessionId)) { return HTTPResponse.json(409, { code: 'fork_pending', error: 'The saved side chat is being updated. Retry the same attempt shortly.', retriable: true }) }
    return Promise.resolve().then(() => {
      const saved = codexSessions.read(sessionId)
      if (!validText(receipt.thread?.id) || !validText(receipt.thread?.cwd, 4096) || !Array.isArray(receipt.thread.turns) || !receipt.thread.turns.length || receipt.thread.status?.type === 'active' || receipt.thread.turns.some(turn => !validText(turn?.id) || !['completed', 'interrupted', 'failed'].includes(turn?.status)) || saved && saved.threadId !== receipt.thread.id || !saved && runnerManager.runners.has(key)) { return HTTPResponse.json(409, { code: 'fork_conflict', error: 'The saved side chat no longer matches this attempt. Open it from task history.', retriable: false }) }
      codexSessions.write(sessionId, { threadId: receipt.thread.id, path: receipt.thread.cwd, provider: 'codex' })
      return HTTPResponse.json(200, { sessionId, threadId: receipt.thread.id, thread: receipt.thread })
    }).catch(() => HTTPResponse.json(502, { code: 'fork_storage_error', error: 'The saved side chat could not be restored. Check host storage and retry this attempt.', retriable: true })).finally(() => codexSessions.release(sessionId))
  }
  if (receipt) { return HTTPResponse.json(409, { code: 'fork_outcome_unknown', error: 'The host could not confirm whether this side chat was created. Check remote task history before starting a new attempt.', retriable: false }) }
  if (codexCompaction.busy(threadId) || runnerManager.runners.has(key) || codexSessions.read(sessionId) || !codexSessions.reserve(sessionId)) {
    return HTTPResponse.json(409, { code: 'fork_conflict', error: 'The source or destination task is busy or already exists. Refresh before starting a side chat.', retriable: false })
  }
  codexSessions.forks.set(key, fingerprint)
  let attempted = false
  let recorded = false
  return Promise.resolve().then(async () => {
    const snapshot = await codexClient.request('thread/read', { threadId, includeTurns: true })
    if (snapshot.thread?.id !== threadId || !Array.isArray(snapshot.thread.turns) || codexCompaction.busy(threadId)) { return HTTPResponse.json(409, { error: 'The source history changed or is unavailable. Refresh before forking it.' }) }
    const completedTurnIds = []
    for (const turn of snapshot.thread.turns) {
      if (!['completed', 'interrupted', 'failed'].includes(turn.status) || !validText(turn.id)) { break }
      completedTurnIds.push(turn.id)
    }
    if (!completedTurnIds.length) { return HTTPResponse.json(409, { error: 'Wait for the first turn to finish before starting a side chat.' }) }
    codexSessions.persist(codexSessions.file(sessionId, 'fork.json'), { fingerprint, status: 'pending' }, true)
    attempted = true
    const result = await codexClient.request('thread/fork', { threadId, lastTurnId: completedTurnIds.at(-1), deferGoalContinuation: true, excludeTurns: false, ...(body.path ? { cwd: body.path } : {}) })
    if (!validText(result.thread?.id) || result.thread.id === threadId || !validText(result.thread?.cwd, 4096) || result.thread.status?.type === 'active' || !Array.isArray(result.thread?.turns) || result.thread.turns.length !== completedTurnIds.length || result.thread.turns.some((turn, index) => turn.id !== completedTurnIds[index] || !['completed', 'interrupted', 'failed'].includes(turn.status))) { return HTTPResponse.json(502, { code: 'fork_outcome_unknown', error: 'The host returned incomplete side-chat history. Check remote task history before starting a new attempt.', retriable: false }) }
    codexSessions.persist(codexSessions.file(sessionId, 'fork.json'), { fingerprint, status: 'completed', thread: result.thread })
    recorded = true
    codexSessions.write(sessionId, { threadId: result.thread.id, path: result.thread.cwd, provider: 'codex' })
    return HTTPResponse.json(200, { sessionId, threadId: result.thread.id, thread: result.thread })
  }).catch(() => HTTPResponse.json(502, { code: attempted && !recorded ? 'fork_outcome_unknown' : recorded ? 'fork_storage_error' : 'fork_preflight_failed', error: attempted && !recorded ? 'The host could not confirm whether this side chat was created. Check remote task history before starting a new attempt.' : 'The side-chat attempt could not be saved. Check the connection and host storage, then retry the same attempt.', retriable: !attempted || recorded })).finally(() => { codexSessions.release(sessionId); codexSessions.forks.delete(key) })
}

export async function steer(request, params) {
  const body = request.json()
  if (typeof body?.prompt !== 'string' || !body.prompt.trim() || body.prompt.length > 32768 || Object.keys(body).some(key => !['prompt', 'requestId', 'receiptOnly'].includes(key)) || body.receiptOnly !== undefined && typeof body.receiptOnly !== 'boolean' || body.receiptOnly === true && !body.requestId || body.requestId !== undefined && (typeof body.requestId !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/iu.test(body.requestId))) { return HTTPResponse.json(400, { error: 'Provide a nonempty steering message up to 32768 characters and an optional UUID requestId.' }) }
  return Promise.resolve().then(async () => {
    if (body.requestId && codexSessions.steeringReceipt(params.id, body.requestId, body.prompt)?.status === 'accepted') { return HTTPResponse.json(200, { ok: true }) }
    if (body.receiptOnly === true) { return HTTPResponse.json(409, { code: 'steer_receipt_unconfirmed', error: 'Delivery has not been confirmed. Check task history before sending another message.' }) }
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

function requestSnapshot(sessionId, includeIdentity = false) {
  const runner = runnerManager.runners.get(sessionId.toLowerCase())
  const threadId = codexSessions.read(sessionId)?.threadId || runner?.threadId || sessionId
  const pending = new Map(codexClient.requestsForThread(threadId).map((request) => [request.requestKey || String(request.id), request]))
  for (const [id, request] of runner?.requests || []) { pending.set(id, request) }
  return { ...(includeIdentity ? { sessionId, threadId } : {}), requests: [...pending.values()].map((request) => ({ requestId: request.requestKey || String(request.id), method: request.method, params: request.params })), agentAttention: codexClient.attentionForThread(threadId).map((request) => ({ threadId: request.params.threadId, requestId: request.requestKey })) }
}

export function requests(request, params) {
  return HTTPResponse.json(200, requestSnapshot(params.id))
}

export function attention(request) {
  if (request.body?.length > 512 * 1024) { return HTTPResponse.json(413, { error: 'payload_too_large' }) }
  const body = request.json()
  if (Object.keys(body).some(key => key !== 'sessionIds') || !Array.isArray(body.sessionIds) || body.sessionIds.length > 100
    || body.sessionIds.some(id => !validText(id)) || new Set(body.sessionIds).size !== body.sessionIds.length) { return HTTPResponse.json(400, { error: 'Provide up to 100 unique nonempty session IDs of at most 512 characters.' }) }
  return HTTPResponse.json(200, { sessions: body.sessionIds.map(id => requestSnapshot(id, true)) })
}

export async function importThread(request, params) {
  const body = request.json()
  if (Object.keys(body).some((key) => !['threadId', 'path', 'includeTurns'].includes(key)) || !validText(body.threadId) || body.path !== undefined && !validText(body.path, 4096) || body.includeTurns !== undefined && typeof body.includeTurns !== 'boolean') { return HTTPResponse.json(400, { error: 'Provide a valid native thread ID and optional includeTurns boolean.' }) }
  if (runnerManager.runners.has(params.id.toLowerCase()) || !codexSessions.reserve(params.id)) { return HTTPResponse.json(409, { error: 'session_conflict' }) }
  return Promise.resolve().then(async () => {
    const result = await codexClient.request('thread/read', { threadId: body.threadId, includeTurns: body.includeTurns !== false })
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
