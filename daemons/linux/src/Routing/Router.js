import HTTPResponse from '../Networking/HTTPResponse.js'
import { abort, resume, start } from '../Handlers/ChatHandler.js'
import { diff, log, status } from '../Handlers/GitHandler.js'
import { list, read, search } from '../Handlers/FilesHandler.js'
import { handle as ping } from '../Handlers/PingHandler.js'
import { updateTitle } from '../Handlers/SessionHandler.js'
import { isAuthorized } from './AuthMiddleware.js'
import { match } from './RouteMatcher.js'

export function handle(request) {
  if (isAuthorized(request)) {
    if (request.method === 'GET') {
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
    }
    if (request.method === 'POST') {
      if (match(request.path, '/sessions/:id/chat')) {
        return start(request, match(request.path, '/sessions/:id/chat'))
      }
      if (match(request.path, '/sessions/:id/chat/abort')) {
        return abort(request, match(request.path, '/sessions/:id/chat/abort'))
      }
      if (match(request.path, '/sessions/:id/title')) {
        return updateTitle(request, match(request.path, '/sessions/:id/title'))
      }
    }
    return HTTPResponse.json(404, { error: 'not_found' })
  }
  return HTTPResponse.json(401, { error: 'unauthorized' })
}
