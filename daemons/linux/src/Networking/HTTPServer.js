import http from 'node:http'
import HTTPRequest from './HTTPRequest.js'
import HTTPResponse from './HTTPResponse.js'
import { handle } from '../Routing/Router.js'
import { isAuthorized } from '../Routing/AuthMiddleware.js'

export default class HTTPServer {
  constructor({ host = '0.0.0.0', port = 8765, handler = handle } = {}) {
    this.host = host
    this.port = port
    this.server = null
    this.handler = handler
  }

  start() {
    const receive = (request, response) => {
      if (!isAuthorized(request)) {
        HTTPResponse.json(401, { error: 'unauthorized' }).send(response)
        return
      }
      if (Number(request.headers['content-length']) > 16 * 1024 * 1024) {
        HTTPResponse.json(413, { error: 'payload_too_large' }).send(response)
        return
      }
      if (request.headers.expect?.toLowerCase() === '100-continue') { response.writeContinue() }
      const controller = new AbortController()
      const chunks = []
      response.once('close', () => {
        chunks.length = 0
        if (!response.writableFinished) { controller.abort() }
      })
      let size = 0
      request.on('data', (chunk) => {
        size += chunk.length
        if (size > 16 * 1024 * 1024) {
          request.removeAllListeners('data')
          request.removeAllListeners('end')
          chunks.length = 0
          request.resume()
          HTTPResponse.json(413, { error: 'payload_too_large' }).send(response)
          return
        }
        chunks.push(chunk)
      })
      request.on('end', () => {
        const body = Buffer.concat(chunks)
        chunks.length = 0
        Promise.resolve()
          .then(() => this.handler(HTTPRequest.fromNode(request, body, controller.signal)))
          .then((result) => { if (!response.destroyed) { result.send(response) } })
          .catch((error) => {
            console.error(`HTTPServer: handler_failed ${request.method} ${request.url}: ${error instanceof SyntaxError ? 'invalid_json' : error.message}`)
            if (response.headersSent) {
              response.destroy()
            } else {
              HTTPResponse.json(error instanceof SyntaxError ? 400 : 500, { error: error instanceof SyntaxError ? 'invalid_json' : 'internal_error' }).send(response)
            }
          })
      })
    }
    this.server = http.createServer(receive)
    this.server.on('checkContinue', receive)
    this.server.requestTimeout = 120000
    this.server.headersTimeout = 15000
    this.server.listen(this.port, this.host, () => {
      console.log(`HTTPServer: listening on ${this.host}:${this.port}`)
    })
  }
}
