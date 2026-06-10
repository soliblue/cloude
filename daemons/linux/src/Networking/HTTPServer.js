import http from 'node:http'
import HTTPRequest from './HTTPRequest.js'
import HTTPResponse from './HTTPResponse.js'
import { handle } from '../Routing/Router.js'

export default class HTTPServer {
  constructor({ host = '0.0.0.0', port = 8765 } = {}) {
    this.host = host
    this.port = port
    this.server = null
  }

  start() {
    this.server = http.createServer((request, response) => {
      let size = 0
      const chunks = []
      request.on('data', (chunk) => {
        size += chunk.length
        if (size > 1_048_576) {
          request.removeAllListeners('data')
          request.removeAllListeners('end')
          request.resume()
          HTTPResponse.json(413, { error: 'payload_too_large' }).send(response)
          return
        }
        chunks.push(chunk)
      })
      request.on('end', () => {
        Promise.resolve()
          .then(() => handle(HTTPRequest.fromNode(request, Buffer.concat(chunks))))
          .then((result) => result.send(response))
          .catch((error) => {
            console.error(`HTTPServer: handler_failed ${request.method} ${request.url}: ${error.message}`)
            if (response.headersSent) {
              response.destroy()
            } else {
              HTTPResponse.json(500, { error: 'internal_error' }).send(response)
            }
          })
      })
    })
    this.server.requestTimeout = 0
    this.server.listen(this.port, this.host, () => {
      console.log(`HTTPServer: listening on ${this.host}:${this.port}`)
    })
  }
}
