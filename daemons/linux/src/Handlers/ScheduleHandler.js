import path from 'node:path'
import { stat } from 'node:fs/promises'
import HTTPResponse from '../Networking/HTTPResponse.js'
import { agentSchedules } from '../Codex/AgentSchedules.js'
import { validSchedule } from '../Codex/ScheduleTime.js'

const uuid = value => typeof value === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(value)
const fields = (value, keys) => value && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).every(key => keys.includes(key))
const text = (value, length) => typeof value === 'string' && value.trim().length > 0 && value.length <= length && !value.includes('\0')

async function validTask(task) {
  return fields(task, ['provider', 'path', 'prompt', 'model', 'effort', 'permissionMode']) && task.provider === 'codex' && text(task.path, 4096) && path.isAbsolute(task.path) && text(task.prompt, 32768) && (task.model === undefined || text(task.model, 128)) && (task.effort === undefined || text(task.effort, 64)) && (task.permissionMode === undefined || ['default', 'plan'].includes(task.permissionMode)) && await stat(task.path).then(file => file.isDirectory(), () => false)
}

export async function schedules(request, params = {}, manager = agentSchedules) {
  try {
    if (params.id && !uuid(params.id)) { return HTTPResponse.json(400, { error: 'Invalid schedule ID.' }) }
    if (params.id) { params = { ...params, id: params.id.toLowerCase() } }
    if (request.method === 'GET') {
      if (!manager.owner.owned) { manager.store.load() }
      if (params.action && params.action !== 'runs') { return HTTPResponse.json(404, { error: 'Schedule route not found.' }) }
      if (!params.id) { return HTTPResponse.json(200, { schedules: manager.store.list(), available: manager.available, ...(!manager.available ? { error: manager.error || manager.store.error || manager.owner.error || 'Scheduling is not ready.' } : {}) }) }
      if (params.action === 'runs') {
        const limit = request.query?.limit === undefined ? 25 : Number(request.query.limit)
        const cursor = request.query?.cursor
        if (!Number.isInteger(limit) || limit < 1 || limit > 100 || cursor !== undefined && !uuid(cursor)) { return HTTPResponse.json(400, { error: 'Invalid run pagination.' }) }
        const runs = manager.store.state.runs.filter(run => run.scheduleId === params.id).slice().reverse()
        const position = cursor ? runs.findIndex(run => run.runId === cursor) + 1 : 0
        if (cursor && position === 0) { return HTTPResponse.json(400, { error: 'Run cursor no longer exists. Reload the first page.' }) }
        return HTTPResponse.json(200, { runs: runs.slice(position, position + limit).map(run => manager.store.runSnapshot(run)), ...(runs.length > position + limit ? { nextCursor: runs[position + limit - 1].runId } : {}) })
      }
      const job = manager.store.get(params.id)
      return job ? HTTPResponse.json(200, manager.store.snapshot(job)) : HTTPResponse.json(404, { error: 'Schedule not found.' })
    }
    manager.requireAvailable()
    let body
    try { body = JSON.parse(request.body.toString('utf8')) } catch { return HTTPResponse.json(400, { error: 'Invalid JSON.' }) }
    if (request.method === 'POST' && params.action === 'run' && fields(body, ['requestId']) && uuid(body.requestId)) { return HTTPResponse.json(202, manager.store.runSnapshot(manager.runNow(params.id, body.requestId.toLowerCase()))) }
    if (request.method === 'DELETE' && !params.action && fields(body, ['revision']) && Number.isSafeInteger(body.revision)) { manager.store.remove(params.id, body.revision); return HTTPResponse.json(200, { ok: true }) }
    const creating = request.method === 'POST' && !params.id
    const updating = request.method === 'POST' && params.action === 'update'
    if (!creating && !updating || !fields(body, creating ? ['requestId', 'name', 'enabled', 'originSessionId', 'task', 'schedule'] : ['revision', 'name', 'enabled', 'originSessionId', 'task', 'schedule']) || creating && !uuid(body.requestId) || updating && (!Number.isSafeInteger(body.revision) || body.revision < 1) || (creating || body.name !== undefined) && !text(body.name, 120) || (creating || body.originSessionId !== undefined) && !uuid(body.originSessionId) || body.enabled !== undefined && typeof body.enabled !== 'boolean' || (creating || body.schedule !== undefined) && !validSchedule(body.schedule) || (creating || body.task !== undefined) && !await validTask(body.task)) { return HTTPResponse.json(400, { error: 'Provide a Codex task, name, origin session UUID, valid schedule and revision. Scheduled tasks support default or plan permissions only.' }) }
    if (body.requestId) { body.requestId = body.requestId.toLowerCase() }
    if (body.originSessionId) { body.originSessionId = body.originSessionId.toLowerCase() }
    if (body.task) { body.task = { provider: 'codex', path: body.task.path, prompt: body.task.prompt, ...(body.task.model ? { model: body.task.model } : {}), ...(body.task.effort ? { effort: body.task.effort } : {}), permissionMode: body.task.permissionMode || 'default' } }
    return HTTPResponse.json(creating ? 201 : 200, creating ? manager.store.create({ requestId: body.requestId, name: body.name, enabled: body.enabled ?? false, originSessionId: body.originSessionId, task: body.task, schedule: body.schedule }) : manager.store.update(params.id, body))
  } catch (error) { return HTTPResponse.json(error.status || 503, { error: error.status ? error.message : 'Schedule storage is unavailable. No new run was started.' }) }
}
