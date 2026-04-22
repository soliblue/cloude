import HTTPResponse from '../Networking/HTTPResponse.js'

export function handle() {
  return HTTPResponse.json(200, { ok: true, serverAt: Date.now() })
}
