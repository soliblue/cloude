import path from 'node:path'
import { homedir } from 'node:os'
import HTTPResponse from '../Networking/HTTPResponse.js'
import { codexClient } from '../Codex/CodexClient.js'

function text(value, maximum = 512) {
  return typeof value === 'string' && value.length > 0 && value.length <= maximum && !/[\u0000-\u001f\u007f]/u.test(value)
}

function validPath(value) {
  return text(value, 4096) && (path.isAbsolute(value) || value === '~' || value.startsWith('~/'))
}

function absolute(value) {
  return value === '~' ? homedir() : value.startsWith('~/') ? path.join(homedir(), value.slice(2)) : path.resolve(value)
}

function fields(value, allowed) {
  return Object.keys(value).every((key) => allowed.includes(key))
}

function boolean(value) {
  return value === undefined || value === 'true' || value === 'false'
}

function page(query, allowed) {
  return fields(query, allowed) && (query.cursor === undefined || text(query.cursor, 4096))
    && (query.limit === undefined || /^[1-9][0-9]?$/u.test(query.limit) || query.limit === '100')
    && (query.threadId === undefined || text(query.threadId))
}

function identity(value) {
  return text(value.pluginName, 255) && (validPath(value.marketplacePath) && value.remoteMarketplaceName === undefined
    || text(value.remoteMarketplaceName, 255) && value.marketplacePath === undefined)
}

function parameters(value) {
  return { pluginName: value.pluginName, ...(value.marketplacePath ? { marketplacePath: absolute(value.marketplacePath) } : { remoteMarketplaceName: value.remoteMarketplaceName }) }
}

function perform(method, params) {
  return codexClient.request(method, params).catch(async (error) => {
    if (['app/list', 'app/installed', 'app/read', 'mcpServerStatus/list'].includes(method) && params.threadId && error.message === `thread not found: ${params.threadId}`) {
      const saved = await codexClient.request('thread/read', { threadId: params.threadId, includeTurns: false })
      if (saved.thread?.id !== params.threadId || saved.thread.status?.type === 'active') { throw error }
      await codexClient.request('thread/resume', { threadId: params.threadId })
      return codexClient.request(method, params)
    }
    throw error
  }).then((result) => HTTPResponse.json(200, result), (error) => HTTPResponse.json(502, {
    error: `Codex ${method} failed: ${String(error.message || 'The host could not complete this request.')
      .replace(/\s*<(?:!doctype|html)\b[\s\S]*/iu, '')
      .replace(/https?:\/\/[^\s"'<>]+/giu, '[URL]')
      .replace(/bearer\s+[^\s"',;]+/giu, 'Bearer [redacted]')
      .replace(/\bsk-[a-z0-9_-]+/giu, '[redacted]')
      .replace(/((?:api[_-]?key|access[_-]?token|refresh[_-]?token|authorization|password|secret)["']?\s*[:=]\s*)["']?[^\s,"';}]+["']?/giu, '$1[redacted]')
      .replace(/[\u0000-\u001f\u007f]/gu, ' ').slice(0, 1000)}`
  }))
}

export function plugins(request) {
  const query = request.query
  if (fields(query, ['path', 'installed', 'forceRefetch']) && boolean(query.installed) && boolean(query.forceRefetch)
    && (query.path === undefined || validPath(query.path)) && !(query.installed === 'true' && query.forceRefetch !== undefined)) {
    return perform(query.installed === 'true' ? 'plugin/installed' : 'plugin/list', {
      ...(query.path ? { cwds: [absolute(query.path)] } : {}), ...(query.installed === 'true' ? {} : { forceRefetch: query.forceRefetch === 'true' })
    })
  }
  return HTTPResponse.json(400, { error: 'Provide an optional absolute path and valid installed or forceRefetch flags.' })
}

export function plugin(request) {
  const value = request.method === 'GET' ? request.query : request.json()
  if (request.method === 'DELETE') {
    if (fields(value, ['pluginId']) && text(value.pluginId)) { return perform('plugin/uninstall', { pluginId: value.pluginId }) }
    return HTTPResponse.json(400, { error: 'A valid pluginId is required.' })
  }
  if (fields(value, ['pluginName', 'marketplacePath', 'remoteMarketplaceName', ...(request.method === 'POST' ? ['installAttemptId'] : [])]) && identity(value)
    && (value.installAttemptId === undefined || text(value.installAttemptId, 128))) {
    return perform(request.method === 'POST' ? 'plugin/install' : 'plugin/read', {
      ...parameters(value), ...(value.installAttemptId ? { installAttemptId: value.installAttemptId } : {})
    })
  }
  return HTTPResponse.json(400, { error: 'Provide pluginName and exactly one absolute marketplacePath or remoteMarketplaceName.' })
}

export function apps(request) {
  const query = request.query
  if (query.installed === 'true') {
    if (fields(query, ['installed', 'threadId', 'forceRefresh']) && boolean(query.forceRefresh) && (query.threadId === undefined || text(query.threadId))) {
      return perform('app/installed', { forceRefresh: query.forceRefresh === 'true', ...(query.threadId ? { threadId: query.threadId } : {}) })
    }
  } else if (page(query, ['installed', 'threadId', 'cursor', 'limit', 'forceRefetch']) && boolean(query.installed) && boolean(query.forceRefetch)) {
    return perform('app/list', { limit: Number(query.limit || 50), forceRefetch: query.forceRefetch === 'true', ...(query.cursor ? { cursor: query.cursor } : {}), ...(query.threadId ? { threadId: query.threadId } : {}) })
  }
  return HTTPResponse.json(400, { error: 'Use valid flags, a thread ID, and a page limit from 1 to 100. Installed apps are not paginated.' })
}

export function readApps(request) {
  const value = request.json()
  if (fields(value, ['appIds', 'includeTools', 'threadId']) && Array.isArray(value.appIds) && value.appIds.length > 0 && value.appIds.length <= 100 && value.appIds.every((id) => text(id))
    && (value.includeTools === undefined || typeof value.includeTools === 'boolean') && (value.threadId === undefined || text(value.threadId))) {
    return perform('app/read', { appIds: [...new Set(value.appIds)], includeTools: value.includeTools === true, ...(value.threadId ? { threadId: value.threadId } : {}) })
  }
  return HTTPResponse.json(400, { error: 'Provide 1 to 100 app IDs, optional includeTools boolean, and optional thread ID.' })
}

export function mcp(request) {
  const query = request.query
  if (page(query, ['threadId', 'cursor', 'limit', 'detail']) && (query.detail === undefined || query.detail === 'toolsAndAuthOnly')) {
    return perform('mcpServerStatus/list', { detail: 'toolsAndAuthOnly', limit: Number(query.limit || 50), ...(query.cursor ? { cursor: query.cursor } : {}), ...(query.threadId ? { threadId: query.threadId } : {}) })
  }
  return HTTPResponse.json(400, { error: 'Use toolsAndAuthOnly detail, optional thread ID and cursor, and a page limit from 1 to 100.' })
}
