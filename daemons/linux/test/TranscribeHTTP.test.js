import test from 'node:test'
import assert from 'node:assert/strict'
import http from 'node:http'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawn } from 'node:child_process'
import { once } from 'node:events'
import HTTPResponse from '../src/Networking/HTTPResponse.js'
import { isTranscribing, transcribe } from '../src/Handlers/TranscribeHandler.js'

const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-transcribe-http-'))
process.env.CLOUDE_DATA = directory
const { default: HTTPServer } = await import('../src/Networking/HTTPServer.js')
const { daemonToken } = await import('../src/Routing/DaemonAuth.js')

const audio = JSON.stringify({ audio: Buffer.from('bounded fixture').toString('base64') })

test('HTTP disconnect cancels only its transcription worker and frees the slot after exit', { timeout: 10000 }, async (t) => {
  let child
  let started
  let closed
  let calls = 0
  const ready = new Promise(resolve => { started = resolve })
  const signals = []
  const server = new HTTPServer({ host: '127.0.0.1', port: 0, handler: request => {
    calls += 1
    signals.push(request.signal)
    assert.equal(request.headers.authorization, `Bearer ${daemonToken()}`)
    if (request.path === '/echo') { return HTTPResponse.json(200, { method: request.method, body: request.body.toString() }) }
    if (request.path === '/stream') { return HTTPResponse.stream(200, 'application/x-ndjson', {}, response => response.end('{"done":true}\n')) }
    return transcribe(request, { ready: () => true, timeout: 5000, createProcess: (_command, _args, options) => {
      child = spawn(process.execPath, ['-e', request.path === '/held'
        ? `process.stdin.resume(); process.stdout.write('ready'); setInterval(() => {}, 1000)`
        : `process.stdin.resume(); process.stdout.write(JSON.stringify({text: 'recovered'}))`], options)
      closed = once(child, 'close')
      child.stdout.once('data', started)
      return child
    } })
  } })
  server.start()
  await once(server.server, 'listening')
  t.after(() => { child?.kill('SIGKILL'); server.server.closeAllConnections(); server.server.close(); fs.rmSync(directory, { recursive: true, force: true }) })
  const url = `http://127.0.0.1:${server.server.address().port}`
  const headers = { Authorization: `Bearer ${daemonToken()}`, 'Content-Type': 'application/json' }
  const held = http.request(`${url}/held`, { method: 'POST', headers })
  held.on('error', () => {})
  held.end(audio)
  await ready
  assert.equal(isTranscribing(), true)
  assert.equal((await fetch(`${url}/next`, { method: 'POST', headers, body: audio })).status, 429)
  held.destroy()
  assert.equal(isTranscribing(), true)
  const [, signal] = await closed
  assert.equal(signal, 'SIGKILL')
  assert.equal(isTranscribing(), false)
  assert.throws(() => process.kill(child.pid, 0), { code: 'ESRCH' })
  assert.deepEqual(await (await fetch(`${url}/next`, { method: 'POST', headers, body: audio })).json(), { text: 'recovered' })
  const completedSignal = signals.at(-1)
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(completedSignal.aborted, false)
  for (const method of ['GET', 'POST']) {
    const body = method === 'POST' ? 'upload bytes' : undefined
    assert.deepEqual(await (await fetch(`${url}/echo`, { method, headers, body })).json(), { method, body: body || '' })
    assert.equal(signals.at(-1).aborted, false)
  }
  assert.equal(await (await fetch(`${url}/stream`, { headers })).text(), '{"done":true}\n')
  assert.equal(signals.at(-1).aborted, false)
  const before = calls
  const connected = once(server.server, 'connection')
  const partial = http.request(`${url}/held`, { method: 'POST', headers: { ...headers, 'Content-Length': 1000 } })
  partial.on('error', () => {})
  partial.write('partial')
  const [socket] = await connected
  const socketClosed = once(socket, 'close').catch(() => {})
  partial.destroy()
  await socketClosed
  assert.equal(calls, before)
  assert.equal(isTranscribing(), false)
})

test('already canceled transcription never spawns and completed jobs remove abort listeners', async () => {
  const canceled = new AbortController()
  canceled.abort()
  assert.equal((await transcribe({ body: Buffer.from(audio), signal: canceled.signal }, {
    ready: () => true, createProcess: () => assert.fail('canceled request spawned')
  })).status, 499)
  const controller = new AbortController()
  let kills = 0
  const result = await transcribe({ body: Buffer.from(audio), signal: controller.signal }, {
    ready: () => true, createProcess: (_command, _args, options) => {
      const child = spawn(process.execPath, ['-e', `process.stdin.resume(); process.stdout.write('{"text":"done"}')`], options)
      const kill = child.kill.bind(child)
      child.kill = signal => { kills += 1; return kill(signal) }
      return child
    }
  })
  assert.equal(result.status, 200)
  controller.abort()
  assert.equal(kills, 0)
})
