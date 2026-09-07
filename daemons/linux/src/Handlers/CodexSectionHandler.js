import HTTPResponse from '../Networking/HTTPResponse.js'
import { codexClient } from '../Codex/CodexClient.js'
import { codexSessions } from '../Codex/CodexSessions.js'
import { THREAD_SOURCE_KINDS } from '../Codex/CodexThreadSources.js'

function text(value, maximum = 512) {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= maximum && !/[\u0000-\u001f\u007f]/u.test(value)
}

function fields(value, allowed) {
  return value && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).every((key) => allowed.includes(key))
}

function page(query) {
  return fields(query, ['cursor', 'limit']) && (query.cursor === undefined || text(query.cursor, 4096))
    && (query.limit === undefined || /^[1-9][0-9]?$/u.test(query.limit) || query.limit === '100')
}

function appearance(value) {
  return value === undefined || value === null || fields(value, ['color', 'icon']) && ['color', 'icon'].every((key) => value[key] === undefined || value[key] === null || text(value[key], 128))
}

function perform(method, params) {
  return codexClient.request(method, params).then((result) => HTTPResponse.json(200, result), (error) => HTTPResponse.json(502, {
    error: `Codex ${method} failed: ${String(error.message || 'The host could not complete this request.')
      .replace(/\s*<(?:!doctype|html)\b[\s\S]*/iu, '')
      .replace(/https?:\/\/[^\s"'<>]+/giu, '[URL]')
      .replace(/bearer\s+[^\s"',;]+/giu, 'Bearer [redacted]')
      .replace(/\bsk-[a-z0-9_-]+/giu, '[redacted]')
      .replace(/((?:api[_-]?key|access[_-]?token|refresh[_-]?token|authorization|password|secret)["']?\s*[:=]\s*)["']?[^\s,"';}]+["']?/giu, '$1[redacted]')
      .replace(/[\u0000-\u001f\u007f]/gu, ' ').slice(0, 1000)}`
  }))
}

export function sections(request) {
  if (request.method === 'GET') {
    if (page(request.query)) { return perform('threadSection/list', { limit: Number(request.query.limit || 50), ...(request.query.cursor ? { cursor: request.query.cursor } : {}) }) }
  } else {
    const value = request.json()
    if (fields(value, ['name', 'appearance']) && text(value.name, 120) && appearance(value.appearance)) {
      return perform('threadSection/create', { name: value.name.trim(), ...(value.appearance !== undefined ? { appearance: value.appearance } : {}) })
    }
  }
  return HTTPResponse.json(400, { error: 'Provide a section name up to 120 characters, or a cursor and page limit from 1 to 100.' })
}

export function updateSection(request, params) {
  const value = request.json()
  if (text(params.id) && fields(value, ['name', 'appearance']) && text(value.name, 120) && appearance(value.appearance)) {
    return perform('threadSection/update', { sectionId: params.id, name: value.name.trim(), ...(value.appearance !== undefined ? { appearance: value.appearance } : {}) })
  }
  return HTTPResponse.json(400, { error: 'Provide a valid section ID and name up to 120 characters.' })
}

export function deleteSection(request, params) {
  if (text(params.id) && fields(request.query, []) && (!request.body.length || fields(request.json(), []) )) { return perform('threadSection/delete', { sectionId: params.id }) }
  return HTTPResponse.json(400, { error: 'Provide a valid section ID and an empty request body.' })
}

export function moveSection(request, params) {
  const value = request.json()
  if (text(params.id) && fields(value, ['sectionId', 'beforeThreadId']) && (value.sectionId === null || text(value.sectionId))
    && (value.beforeThreadId === undefined || value.beforeThreadId === null || text(value.beforeThreadId))) {
    return perform('thread/section/move', { threadId: codexSessions.read(params.id)?.threadId || params.id, sectionId: value.sectionId, ...(value.beforeThreadId !== undefined ? { beforeThreadId: value.beforeThreadId } : {}) })
  }
  return HTTPResponse.json(400, { error: 'Provide a sectionId or null to remove the task, and an optional native beforeThreadId.' })
}

export function sectionThreads(request, params) {
  if (text(params.id) && page(request.query)) {
    return perform('thread/list', { sectionId: params.id, sourceKinds: THREAD_SOURCE_KINDS, sortKey: 'section_position', sortDirection: 'asc', useStateDbOnly: true, limit: Number(request.query.limit || 50), ...(request.query.cursor ? { cursor: request.query.cursor } : {}) })
  }
  return HTTPResponse.json(400, { error: 'Provide a section ID, optional cursor, and page limit from 1 to 100.' })
}
