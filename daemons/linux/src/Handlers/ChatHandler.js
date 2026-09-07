import { validReviewTarget } from '../Codex/CodexReviewTarget.js'
import { codexCompaction } from '../Codex/CodexCompaction.js'
import HTTPResponse from '../Networking/HTTPResponse.js'
import path from 'node:path'
import os from 'node:os'
import { runnerManager } from '../RunnerManager.js'
import { replay } from './SessionJSONLReplay.js'
import { codexSessions } from '../Codex/CodexSessions.js'
import { codexClient } from '../Codex/CodexClient.js'

function parsedBody(request) {
  try {
    return JSON.parse(request.body.toString('utf8'))
  } catch {
    return null
  }
}

export function start(request, params) {
  const body = parsedBody(request)
  if (params.id && codexSessions.busy(params.id)) { return HTTPResponse.json(409, { error: 'session_update_pending', message: 'A task update is in progress. Retry when it finishes.' }) }
  if (body?.shellCommand !== undefined && (body.provider !== 'codex' || typeof body.shellCommand !== 'string' || !body.shellCommand.trim() || body.shellCommand.length > 16384 || body.reviewTarget !== undefined || ['images', 'skills', 'mentions'].some((key) => body[key] !== undefined && (!Array.isArray(body[key]) || body[key].length > 0)))) {
    return HTTPResponse.json(400, { error: 'Provide a Codex shell command up to 16384 characters without images, references, or a review target.' })
  }
  if (body?.reviewTarget !== undefined && (body.provider !== 'codex' || !validReviewTarget(body.reviewTarget))) {
    return HTTPResponse.json(400, { error: 'Provide a valid Codex review target: uncommittedChanges, baseBranch, commit, or custom.' })
  }
  if (body?.provider && !['claude', 'codex'].includes(body.provider)) {
    return HTTPResponse.json(400, { error: 'unsupported_provider' })
  }
  if (body?.provider === 'codex' && (codexClient.activeTurns.has(body.threadId || codexSessions.read(params.id)?.threadId) || codexCompaction.busy(body.threadId || codexSessions.read(params.id)?.threadId) || runnerManager.runners.has(params.id.toLowerCase()) || [...runnerManager.runners.values()].some((runner) => runner.threadId && runner.threadId === (body.threadId || codexSessions.read(params.id)?.threadId)))) {
    return HTTPResponse.json(409, { error: 'turn_already_running', message: 'Steer or interrupt the active turn before starting another.' })
  }
  if (params.id && typeof body?.path === 'string' && body.path.length > 0 && typeof body?.prompt === 'string') {
    return HTTPResponse.stream(200, 'application/x-ndjson', {}, (response) => {
      runnerManager.start({
        sessionId: params.id,
        provider: body.provider,
        reviewTarget: body.reviewTarget,
        shellCommand: body.shellCommand,
        skills: Array.isArray(body.skills) ? body.skills : [],
        mentions: Array.isArray(body.mentions) ? body.mentions : [],
        projectId: typeof body.projectId === 'string' ? body.projectId : null,
        threadId: typeof body.threadId === 'string' ? body.threadId : null,
        path: body.path === '~' ? os.homedir() : body.path.startsWith('~/') ? path.join(os.homedir(), body.path.slice(2)) : path.resolve(body.path),
        prompt: body.prompt,
        images: Array.isArray(body.images) ? body.images : [],
        existsOnServer: body.existsOnServer === true,
        model: typeof body.model === 'string' ? body.model : null,
        effort: typeof body.effort === 'string' ? body.effort : null,
        permissionMode: typeof body.permissionMode === 'string' ? body.permissionMode : null,
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
      if (!attached && !codexSessions.replay(params.id, response) && !replay(params.id, response)) {
        response.end()
      }
    })
  }
  return HTTPResponse.json(400, { error: 'bad_request' })
}

export async function abort(request, params) {
  if (params.id) {
    if (runnerManager.abort(params.id)) { return HTTPResponse.json(200, { ok: true, aborted: true }) }
    const saved = codexSessions.read(params.id)
    if (!saved?.threadId || saved.provider !== 'codex') { return HTTPResponse.json(200, { ok: true, aborted: false }) }
    return codexClient.request('thread/read', { threadId: saved.threadId, includeTurns: true }).then(async (result) => {
      if (result.thread?.id !== saved.threadId) { return HTTPResponse.json(409, { error: 'The host returned a different task. Refresh before stopping it.' }) }
      if (result.thread.status?.type !== 'active') { return HTTPResponse.json(200, { ok: true, aborted: false }) }
      const turn = result.thread.turns?.at(-1)
      if (turn?.status !== 'inProgress' || typeof turn.id !== 'string' || !turn.id) { return HTTPResponse.json(409, { error: 'The active turn is not available yet. Refresh the task and try again.' }) }
      await codexClient.request('turn/interrupt', { threadId: saved.threadId, turnId: turn.id })
      return HTTPResponse.json(200, { ok: true, aborted: true, threadId: saved.threadId, turnId: turn.id })
    }).catch(() => HTTPResponse.json(502, { error: 'The host could not interrupt this task. Refresh its status and try again.' }))
  }
  return HTTPResponse.json(400, { error: 'bad_request' })
}
