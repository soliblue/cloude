import { split } from '../Routing/RouteMatcher.js'

export default class HTTPRequest {
  constructor(method, path, query, headers, body) {
    this.method = method
    this.path = path
    this.query = query
    this.headers = headers
    this.body = body
  }

  static fromNode(request, body) {
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
      body
    )
  }
}
