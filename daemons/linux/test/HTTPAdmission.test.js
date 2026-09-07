import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import net from 'node:net'
import { once } from 'node:events'
import HTTPResponse from '../src/Networking/HTTPResponse.js'

const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-http-admission-'))
process.env.CLOUDE_DATA = directory
const { default: HTTPServer } = await import('../src/Networking/HTTPServer.js')
const { daemonToken } = await import('../src/Routing/DaemonAuth.js')

test('HTTP authenticates and bounds declared bodies before reading or allowing continue', { timeout: 10000 }, async t => {
  const calls = []
  const server = new HTTPServer({ host: '127.0.0.1', port: 0, handler: request => {
    calls.push(request)
    return HTTPResponse.json(200, { body: request.body.toString() })
  } })
  server.start()
  await once(server.server, 'listening')
  t.after(() => { server.server.closeAllConnections(); server.server.close(); fs.rmSync(directory, { recursive: true, force: true }) })
  const exchange = async headers => {
    const socket = net.connect(server.server.address().port, '127.0.0.1')
    socket.on('error', () => {})
    await once(socket, 'connect')
    let response = ''
    socket.on('data', chunk => { response += chunk })
    socket.write(`POST /test HTTP/1.1\r\nHost: localhost\r\n${headers}\r\n\r\n`)
    await new Promise(resolve => socket.once('close', resolve))
    return response
  }
  for (const expect of ['', '\r\nExpect: 100-continue']) {
    const unauthorized = await exchange(`Content-Length: 1024${expect}`)
    assert.match(unauthorized, /^HTTP\/1.1 401 /)
    assert.doesNotMatch(unauthorized, /100 Continue/)
    const invalid = await exchange(`Authorization: Bearer incorrect\r\nContent-Length: 1024${expect}`)
    assert.match(invalid, /^HTTP\/1.1 401 /)
    const oversized = await exchange(`Authorization: Bearer ${daemonToken()}\r\nContent-Length: 16777217${expect}`)
    assert.match(oversized, /^HTTP\/1.1 413 /)
    assert.doesNotMatch(oversized, /100 Continue/)
  }
  assert.equal(calls.length, 0)
  const socket = net.connect(server.server.address().port, '127.0.0.1')
  await once(socket, 'connect')
  let response = ''
  socket.on('data', chunk => { response += chunk })
  socket.write(`POST /test HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer ${daemonToken()}\r\nContent-Length: 5\r\nExpect: 100-continue\r\n\r\n`)
  await once(socket, 'data')
  assert.equal(response, 'HTTP/1.1 100 Continue\r\n\r\n')
  assert.equal(calls.length, 0)
  socket.write('hello')
  await new Promise(resolve => socket.once('close', resolve))
  assert.match(response, /HTTP\/1.1 200 /)
  assert.match(response, /"body":"hello"/)
  assert.equal(calls.length, 1)
  assert.equal(calls[0].signal.aborted, false)
  const chunked = net.connect(server.server.address().port, '127.0.0.1')
  chunked.on('error', () => {})
  await once(chunked, 'connect')
  let rejected = ''
  chunked.on('data', chunk => { rejected += chunk })
  const closed = new Promise(resolve => chunked.once('close', resolve))
  chunked.write(`POST /test HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer ${daemonToken()}\r\nTransfer-Encoding: chunked\r\n\r\n`)
  const block = Buffer.alloc(1024 * 1024, 97)
  for (let index = 0; index < 17; index += 1) {
    chunked.write('100000\r\n')
    chunked.write(block)
    chunked.write('\r\n')
  }
  await closed
  assert.match(rejected, /^HTTP\/1.1 413 /)
  assert.equal(calls.length, 1)
  const good = await fetch(`http://127.0.0.1:${server.server.address().port}/test`, { headers: { Authorization: `Bearer ${daemonToken()}` } })
  assert.equal(good.status, 200)
  assert.equal(calls.length, 2)
})
