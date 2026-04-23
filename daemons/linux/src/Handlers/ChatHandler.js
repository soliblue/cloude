import HTTPResponse from '../Networking/HTTPResponse.js'
import { runnerManager } from '../RunnerManager.js'
import { replay } from './SessionJSONLReplay.js'

function parsedBody(request) {
  try {
    return JSON.parse(request.body.toString('utf8'))
  } catch {
    return null
  }
}

export function start(request, params) {
  const body = parsedBody(request)
  if (params.id && body?.path && body?.prompt) {
    return HTTPResponse.stream(200, 'application/x-ndjson', {}, (response) => {
      runnerManager.start({
        sessionId: params.id,
        path: body.path,
        prompt: body.prompt,
        images: Array.isArray(body.images) ? body.images : [],
        existsOnServer: body.existsOnServer === true,
        model: typeof body.model === 'string' ? body.model : null,
        effort: typeof body.effort === 'string' ? body.effort : null,
        response
      })
    })
  }
  return HTTPResponse.json(400, { error: 'bad_request' })
}

export function resume(request, params) {
  if (params.id) {
    return HTTPResponse.stream(200, 'application/x-ndjson', {}, (response) => {
      const parsed = Number.parseInt(request.query.after_seq || '-1', 10)
      const afterSeq = Number.isNaN(parsed) ? -1 : parsed
      const attached = runnerManager.resumeIfExists(params.id, afterSeq, response)
      if (!attached && !replay(params.id, response)) {
        response.end()
      }
    })
  }
  return HTTPResponse.json(400, { error: 'bad_request' })
}

export function abort(request, params) {
  if (params.id) {
    const aborted = runnerManager.abort(params.id)
    return HTTPResponse.json(200, { ok: true, aborted })
  }
  return HTTPResponse.json(400, { error: 'bad_request' })
}
