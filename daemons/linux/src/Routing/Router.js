import { schedules } from '../Handlers/ScheduleHandler.js'
import { terminal } from '../Handlers/TerminalHandler.js'
import { sections, updateSection, deleteSection, moveSection, sectionThreads } from '../Handlers/CodexSectionHandler.js'
import { plugins, plugin, apps, readApps, mcp } from '../Handlers/CodexPluginHandler.js'
import HTTPResponse from '../Networking/HTTPResponse.js'
import { register as registerPush } from '../Handlers/PushHandler.js'
import { models, account, limits, threads, history, fork, steer, respond, archive, requests, importThread, rename, skills, modes, goal, projects, createProject, login, compact } from '../Handlers/CodexHandler.js'
import { abort, resume, start } from '../Handlers/ChatHandler.js'
import { uploadIOSLog } from '../Handlers/DebugHandler.js'
import { commit, diff, log, status, mutate, worktrees, branches, createWorktree } from '../Handlers/GitHandler.js'
import { list, read, search } from '../Handlers/FilesHandler.js'
import { manifest } from '../Handlers/SessionManifestHandler.js'
import { transcribe } from '../Handlers/TranscribeHandler.js'
import { handle as ping } from '../Handlers/PingHandler.js'
import { updateTitle } from '../Handlers/SessionHandler.js'
import { isAuthorized } from './AuthMiddleware.js'
import { match } from './RouteMatcher.js'

export function handle(request) {
  if (isAuthorized(request)) {
    for (const route of ['/schedules/:id/:action', '/schedules/:id', '/schedules']) {
      if (match(request.path, route)) { return schedules(request, match(request.path, route)) }
    }
    for (const route of ['/sessions/:id/terminals/:terminalId/:action', '/sessions/:id/terminals/:terminalId', '/sessions/:id/terminals']) {
      if (match(request.path, route)) { return terminal(request, match(request.path, route)) }
    }
    if (['GET', 'POST'].includes(request.method) && request.path === '/codex/sections') { return sections(request) }
    if (request.method === 'POST' && match(request.path, '/codex/sections/:id/update')) { return updateSection(request, match(request.path, '/codex/sections/:id/update')) }
    if (request.method === 'DELETE' && match(request.path, '/codex/sections/:id')) { return deleteSection(request, match(request.path, '/codex/sections/:id')) }
    if (request.method === 'GET' && match(request.path, '/codex/sections/:id/threads')) { return sectionThreads(request, match(request.path, '/codex/sections/:id/threads')) }
    if (request.method === 'POST' && match(request.path, '/sessions/:id/section')) { return moveSection(request, match(request.path, '/sessions/:id/section')) }
    if (['GET', 'POST'].includes(request.method) && match(request.path, '/sessions/:id/compact')) { return compact(request, match(request.path, '/sessions/:id/compact')) }
    if (request.method === 'GET' && request.path === '/codex/plugins') { return plugins(request) }
    if (['GET', 'POST', 'DELETE'].includes(request.method) && request.path === '/codex/plugin') { return plugin(request) }
    if (request.method === 'GET' && request.path === '/codex/apps') { return apps(request) }
    if (request.method === 'POST' && request.path === '/codex/apps/read') { return readApps(request) }
    if (request.method === 'GET' && request.path === '/codex/mcp') { return mcp(request) }
    if (['GET', 'POST', 'DELETE'].includes(request.method) && request.path === '/codex/login') { return login(request) }
    if (['GET', 'POST', 'DELETE'].includes(request.method) && match(request.path, '/sessions/:id/goal')) { return goal(request, match(request.path, '/sessions/:id/goal')) }
    if (request.method === 'PUT' && request.path === '/push/device') { return registerPush(request) }
    if (request.method === 'GET') {
      if (match(request.path, '/sessions/:id/git/worktrees')) { return worktrees(request) }
      if (match(request.path, '/sessions/:id/git/branches')) { return branches(request) }
      if (match(request.path, '/sessions/:id/chat/requests')) { return requests(request, match(request.path, '/sessions/:id/chat/requests')) }
      if (request.path === '/codex/skills') { return skills(request) }
      if (request.path === '/codex/modes') { return modes(request) }
      if (request.path === '/codex/projects') { return projects(request) }
      if (request.path === '/codex/models') { return models(request) }
      if (request.path === '/codex/account') { return account(request) }
      if (request.path === '/codex/limits') { return limits(request) }
      if (match(request.path, '/codex/threads/:id')) { return history(request, match(request.path, '/codex/threads/:id')) }
      if (request.path === '/codex/threads') { return threads(request) }
      if (match(request.path, '/sessions/:id/history')) { return history(request, match(request.path, '/sessions/:id/history')) }
      if (request.path === '/ping') {
        return ping(request)
      }
      if (match(request.path, '/sessions/:id/files')) {
        return list(request, match(request.path, '/sessions/:id/files'))
      }
      if (match(request.path, '/sessions/:id/files/read')) {
        return read(request, match(request.path, '/sessions/:id/files/read'))
      }
      if (match(request.path, '/sessions/:id/files/search')) {
        return search(request, match(request.path, '/sessions/:id/files/search'))
      }
      if (match(request.path, '/sessions/:id/manifest')) {
        return manifest(request, match(request.path, '/sessions/:id/manifest'))
      }
      if (match(request.path, '/sessions/:id/chat/resume')) {
        return resume(request, match(request.path, '/sessions/:id/chat/resume'))
      }
      if (match(request.path, '/sessions/:id/git/status')) {
        return status(request, match(request.path, '/sessions/:id/git/status'))
      }
      if (match(request.path, '/sessions/:id/git/diff')) {
        return diff(request, match(request.path, '/sessions/:id/git/diff'))
      }
      if (match(request.path, '/sessions/:id/git/log')) {
        return log(request, match(request.path, '/sessions/:id/git/log'))
      }
      if (match(request.path, '/sessions/:id/git/commit')) {
        return commit(request, match(request.path, '/sessions/:id/git/commit'))
      }
    }
    if (request.method === 'POST') {
      if (match(request.path, '/sessions/:id/git/worktrees')) { return createWorktree(request) }
      if (request.path === '/codex/projects') { return createProject(request) }
      if (match(request.path, '/sessions/:id/git/mutate')) { return mutate(request, match(request.path, '/sessions/:id/git/mutate')) }
      if (match(request.path, '/sessions/:id/name')) { return rename(request, match(request.path, '/sessions/:id/name')) }
      if (match(request.path, '/sessions/:id/import')) { return importThread(request, match(request.path, '/sessions/:id/import')) }
      if (match(request.path, '/sessions/:id/fork')) { return fork(request, match(request.path, '/sessions/:id/fork')) }
      if (match(request.path, '/sessions/:id/archive')) { return archive(request, match(request.path, '/sessions/:id/archive')) }
      if (match(request.path, '/sessions/:id/chat/steer')) { return steer(request, match(request.path, '/sessions/:id/chat/steer')) }
      if (match(request.path, '/sessions/:id/chat/respond')) { return respond(request, match(request.path, '/sessions/:id/chat/respond')) }
      if (match(request.path, '/sessions/:id/chat')) {
        return start(request, match(request.path, '/sessions/:id/chat'))
      }
      if (match(request.path, '/sessions/:id/chat/abort')) {
        return abort(request, match(request.path, '/sessions/:id/chat/abort'))
      }
      if (match(request.path, '/sessions/:id/transcribe')) {
        return transcribe(request, match(request.path, '/sessions/:id/transcribe'))
      }
      if (match(request.path, '/sessions/:id/title')) {
        return updateTitle(request, match(request.path, '/sessions/:id/title'))
      }
      if (request.path === '/debug/ios-log') {
        return uploadIOSLog(request)
      }
    }
    return HTTPResponse.json(404, { error: 'not_found' })
  }
  return HTTPResponse.json(401, { error: 'unauthorized' })
}
