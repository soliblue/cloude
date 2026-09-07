import { split } from '../Routing/RouteMatcher.js'

export default class HTTPRequest {
  constructor(method, path, query, headers, body, signal) {
    this.method = method
    this.path = path
    this.query = query
    this.headers = headers
    this.body = body
    this.signal = signal
  }

  json() {
    const value = JSON.parse(this.body.toString('utf8'))
    if (value && typeof value === 'object' && !Array.isArray(value)) { return value }
    throw new SyntaxError('Expected a JSON object')
  }

  static fromNode(request, body, signal) {
    const { path, query } = split(request.url || '/')
    return new HTTPRequest(
      request.method || 'GET',
      path,
      query,
      Object.fromEntries(
        Object.entries(request.headers).map(([key, value]) => [
          key.toLowerCase(),
          Array.isArray(value) ? value.join(', ') : value || ''
        ])
      ),
      body,
      signal
    )
  }
}
