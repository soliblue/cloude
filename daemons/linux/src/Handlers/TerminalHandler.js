import path from 'node:path'
import HTTPResponse from '../Networking/HTTPResponse.js'
import { codexTerminal } from '../Codex/CodexTerminal.js'

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const dimensions = body => ['cols', 'rows'].every(key => body[key] === undefined || Number.isInteger(body[key]) && body[key] >= 1 && body[key] <= 1000)
const fields = (body, keys) => body && typeof body === 'object' && !Array.isArray(body) && Object.keys(body).every(key => keys.includes(key))

export async function terminal(request, params, manager = codexTerminal) {
  if (!params.id || params.id.length > 512) { return HTTPResponse.json(400, { error: 'Invalid task ID.' }) }
  let body = {}
  try { body = request.body?.length ? JSON.parse(request.body.toString('utf8')) : {} } catch { return HTTPResponse.json(400, { error: 'Invalid JSON.' }) }
  if (!params.terminalId) {
    if (request.method === 'GET') { return HTTPResponse.json(200, { terminals: manager.list(params.id) }) }
    if (request.method !== 'POST' || !fields(body, ['requestId', 'path', 'fullAccess', 'cols', 'rows']) || !(typeof body.requestId === 'string' && uuid.test(body.requestId)) || typeof body.path !== 'string' || body.path.length > 4096 || body.path.includes('\0') || !path.isAbsolute(body.path) || body.fullAccess !== true || !dimensions(body)) { return HTTPResponse.json(400, { error: 'Provide a request UUID, existing absolute path, valid terminal size, and explicit fullAccess:true.' }) }
    const result = await manager.start(params.id, body)
    return HTTPResponse.json(result.status, result.body)
  }
  const entry = manager.get(params.id, params.terminalId)
  if (!entry) { return HTTPResponse.json(404, { error: 'This terminal is unavailable on this task. Open a new terminal if the host restarted.' }) }
  if (request.method === 'GET' && params.action === 'stream') {
    const cursor = request.query?.after_seq ?? '-1'
    if (!/^-?\d+$/.test(cursor) || !Number.isSafeInteger(Number(cursor)) || Number(cursor) < -1 || Number(cursor) > entry.seq) { return HTTPResponse.json(400, { error: 'Invalid terminal stream cursor.' }) }
    return HTTPResponse.stream(200, 'application/x-ndjson', {}, response => manager.subscribe(entry, Number(cursor), response))
  }
  let result
  if (request.method === 'DELETE' && !params.action && fields(body, [])) { result = entry.status === 'running' ? await manager.control(entry, 'terminate', {}) : { status: 200, body: manager.snapshot(entry) } }
  if (request.method === 'POST' && params.action === 'resize' && fields(body, ['cols', 'rows']) && body.cols !== undefined && body.rows !== undefined && dimensions(body)) { result = await manager.control(entry, 'resize', { size: body }) }
  if (request.method === 'POST' && params.action === 'input' && fields(body, ['writerId', 'sequence', 'deltaBase64', 'closeStdin']) && typeof body.writerId === 'string' && uuid.test(body.writerId) && Number.isSafeInteger(body.sequence) && body.sequence >= 0 && (body.closeStdin === undefined || typeof body.closeStdin === 'boolean') && (body.deltaBase64 === undefined || typeof body.deltaBase64 === 'string' && body.deltaBase64.length <= 87384 && /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(body.deltaBase64) && Buffer.from(body.deltaBase64, 'base64').length <= 65536) && (body.deltaBase64?.length || body.closeStdin === true)) { result = await manager.input(entry, body) }
  return result ? HTTPResponse.json(result.status, result.body) : HTTPResponse.json(400, { error: 'Invalid terminal action or input. Input needs a writer UUID, ordered sequence and at most 64 KiB of base64 bytes.' })
}
