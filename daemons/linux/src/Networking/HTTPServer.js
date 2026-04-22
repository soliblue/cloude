import http from 'node:http'
import HTTPRequest from './HTTPRequest.js'
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
          request.destroy()
          return
        }
        chunks.push(chunk)
      })
      request.on('end', () => {
        handle(HTTPRequest.fromNode(request, Buffer.concat(chunks))).send(response)
      })
    })
    this.server.requestTimeout = 0
    this.server.listen(this.port, this.host, () => {
      console.log(`HTTPServer: listening on ${this.host}:${this.port}`)
    })
  }
}
