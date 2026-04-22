export default class HTTPResponse {
  constructor(status, body, contentType = 'application/json', extraHeaders = {}, streamer = null) {
    this.status = status
    this.body = body
    this.contentType = contentType
    this.extraHeaders = extraHeaders
    this.streamer = streamer
  }

  static json(status, object) {
    return new HTTPResponse(status, Buffer.from(JSON.stringify(object ?? {})))
  }

  static text(status, string) {
    return new HTTPResponse(status, Buffer.from(string), 'text/plain; charset=utf-8')
  }

  static stream(status = 200, contentType = 'application/x-ndjson', extraHeaders = {}, streamer) {
    return new HTTPResponse(status, null, contentType, extraHeaders, streamer)
  }

  send(response) {
    response.statusCode = this.status
    response.setHeader('Content-Type', this.contentType)
    for (const [key, value] of Object.entries(this.extraHeaders)) {
      response.setHeader(key, value)
    }
    response.setHeader('Connection', 'close')
    if (this.streamer) {
      if (typeof response.flushHeaders === 'function') {
        response.flushHeaders()
      }
      this.streamer(response)
      return
    }
    response.setHeader('Content-Length', this.body.length)
    response.end(this.body)
  }
}
