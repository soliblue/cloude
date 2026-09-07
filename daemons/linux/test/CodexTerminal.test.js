import test from 'node:test'
import assert from 'node:assert/strict'
import { EventEmitter } from 'node:events'
import { randomUUID } from 'node:crypto'
import os from 'node:os'
import CodexTerminal from '../src/Codex/CodexTerminal.js'
import { terminal } from '../src/Handlers/TerminalHandler.js'

class Client extends EventEmitter {
  constructor() { super(); this.calls = []; this.executions = new Map() }
  request(method, params, timeout) {
    this.calls.push({ method, params, timeout })
    if (method === 'account/read') { return Promise.resolve({ account: { type: 'chatgpt' } }) }
    if (method === 'command/exec') { return new Promise((resolve, reject) => this.executions.set(params.processId, { resolve, reject })) }
    return Promise.resolve({ config: {} })
  }
}
class Response extends EventEmitter {
  constructor() { super(); this.lines = []; this.ended = false }
  write(line) { this.lines.push(line); return true }
  end() { this.ended = true; this.emit('close') }
  events() { return this.lines.filter(line => line.trim()).map(line => JSON.parse(line)) }
}
const request = (method, body = {}, query = {}) => ({ method, body: Buffer.from(JSON.stringify(body)), query })
const newTerminal = () => ({ requestId: randomUUID(), path: os.tmpdir(), fullAccess: true, cols: 80, rows: 24 })

test('terminal create retries share exactly one inference-free native PTY and preserve current state', async () => {
  const client = new Client(), manager = new CodexTerminal(client)
  try {
    const body = newTerminal()
    const [first, second] = await Promise.all([manager.start('TASK', body), manager.start('task', body)])
    assert.equal(first.body.terminalId, second.body.terminalId)
    assert.equal(client.calls.filter(call => call.method === 'command/exec').length, 1)
    const exec = client.calls.find(call => call.method === 'command/exec')
    assert.equal(exec.timeout, null)
    assert.equal(exec.params.disableTimeout, true)
    assert.equal(exec.params.disableOutputCap, true)
    assert.deepEqual(exec.params.env, { TERM: 'xterm-256color', COLORTERM: 'truecolor' })
    assert.deepEqual(exec.params.sandboxPolicy, { type: 'dangerFullAccess' })
    assert.ok(client.calls.every(call => !/turn|rateLimits|thread/.test(call.method)))
    assert.equal((await manager.start('task', { ...body, rows: 99 })).status, 409)
    client.executions.get(first.body.terminalId).resolve({ exitCode: 0 })
    await new Promise(resolve => setImmediate(resolve))
    assert.equal((await manager.start('task', body)).body.status, 'exited')
  } finally { manager.close() }
})

test('output replay is ordered, bounded, gap explicit, resize replayable, and phone close never kills terminal', async () => {
  const client = new Client(), manager = new CodexTerminal(client, { bufferLimit: 1000 })
  try {
    const start = await manager.start('task', newTerminal()), entry = manager.get('task', start.body.terminalId)
    const live = new Response()
    manager.subscribe(entry, -1, live)
    for (let i = 0; i < 20; i++) { client.emit('notification', { method: 'command/exec/outputDelta', params: { processId: entry.terminalId, deltaBase64: Buffer.from(`line${i}\n`).toString('base64'), stream: 'stdout', capReached: false } }) }
    assert.equal(live.events().filter(event => event.type === 'terminal_output').length, 20)
    assert.ok(entry.bytes <= 1000)
    live.end()
    assert.equal(entry.status, 'running')
    assert.equal(client.calls.filter(call => call.method.endsWith('/terminate')).length, 0)
    await manager.control(entry, 'resize', { size: { cols: 100, rows: 30 } })
    const replay = new Response()
    manager.subscribe(entry, -1, replay)
    assert.equal(replay.events()[0].type, 'terminal_gap')
    assert.equal(replay.events()[0].requestedAfterSeq, -1)
    assert.equal(replay.events().at(-1).cols, 100)
    assert.equal(replay.events().at(-1).rows, 30)
    client.executions.get(entry.terminalId).resolve({ exitCode: 7 })
    await new Promise(resolve => setImmediate(resolve))
    assert.equal(replay.events().at(-1).exitCode, 7)
    assert.equal(replay.ended, true)
  } finally { manager.close() }
})

test('terminal stdin writes are serialized, idempotent, scoped, bounded and never auto-retried', async () => {
  const client = new Client(), manager = new CodexTerminal(client)
  try {
    const start = await manager.start('task', newTerminal()), entry = manager.get('task', start.body.terminalId)
    const input = { writerId: randomUUID(), sequence: 0, deltaBase64: Buffer.from('echo test\n').toString('base64') }
    const results = await Promise.all([manager.input(entry, input), manager.input(entry, input)])
    assert.deepEqual(results[0], results[1])
    assert.equal(client.calls.filter(call => call.method === 'command/exec/write').length, 1)
    assert.equal((await manager.input(entry, { ...input, deltaBase64: 'YQ==' })).status, 409)
    assert.equal((await terminal(request('POST', input), { id: 'foreign', terminalId: entry.terminalId, action: 'input' }, manager)).status, 404)
    for (const body of [{ deltaBase64: 'YQ==' }, { writerId: randomUUID(), sequence: 0, deltaBase64: '*bad*' }, { writerId: randomUUID(), sequence: 0, deltaBase64: Buffer.alloc(65537).toString('base64') }, { writerId: randomUUID(), sequence: 0, closeStdin: 'yes' }]) {
      assert.equal((await terminal(request('POST', body), { id: 'task', terminalId: entry.terminalId, action: 'input' }, manager)).status, 400)
    }
    assert.equal(client.calls.filter(call => call.method === 'command/exec/write').length, 1)
  } finally { manager.close() }
})

test('terminal lifecycle caps live processes and expires only finished entries after disconnect', async () => {
  let clock = 0
  const client = new Client(), manager = new CodexTerminal(client, { now: () => clock, retainedMs: 100 })
  try {
    await Promise.all(Array.from({ length: 4 }, () => manager.start('task', newTerminal())))
    assert.equal((await manager.start('task', newTerminal())).status, 409)
    clock = 999999999
    manager.sweep()
    assert.equal(manager.list('task').length, 4)
    assert.equal(client.calls.filter(call => call.method.endsWith('/terminate')).length, 0)
    client.emit('disconnected')
    assert.ok(manager.list('task').every(entry => entry.status === 'failed'))
    clock += 101
    manager.sweep()
    assert.equal(manager.list('task').length, 0)
  } finally { manager.close() }
})

test('terminal route rejects absent consent, bad dimensions and arbitrary environment before RPC', async () => {
  const client = new Client(), manager = new CodexTerminal(client)
  try {
    for (const body of [{ ...newTerminal(), fullAccess: false }, { ...newTerminal(), rows: 0 }, { ...newTerminal(), path: 'relative' }, { ...newTerminal(), env: { EVIL: 'yes' } }]) {
      assert.equal((await terminal(request('POST', body), { id: 'task' }, manager)).status, 400)
    }
    assert.equal(client.calls.length, 0)
    client.request = async method => method === 'account/read' ? { account: { type: 'apiKey' } } : { config: {} }
    assert.equal((await manager.start('task', newTerminal())).status, 502)
    assert.equal(manager.entries.size, 0)
  } finally { manager.close() }
})

test('stdin order waits for each native acknowledgement and caches uncertain outcomes without duplicate writes', async () => {
  const client = new Client(), manager = new CodexTerminal(client)
  try {
    const start = await manager.start('task', newTerminal()), entry = manager.get('task', start.body.terminalId)
    const native = client.request.bind(client)
    const waiting = []
    client.request = (method, params, timeout) => method === 'command/exec/write' ? new Promise((resolve, reject) => { client.calls.push({ method, params }); waiting.push({ resolve, reject }) }) : native(method, params, timeout)
    const one = { writerId: randomUUID(), sequence: 0, deltaBase64: 'YQ==' }, two = { writerId: randomUUID(), sequence: 0, deltaBase64: 'Yg==' }
    const first = manager.input(entry, one), second = manager.input(entry, two)
    await new Promise(resolve => setImmediate(resolve))
    assert.equal(waiting.length, 1)
    waiting[0].reject(new Error('secret-bearing failure'))
    assert.equal((await first).status, 502)
    await new Promise(resolve => setImmediate(resolve))
    assert.equal(waiting.length, 2)
    waiting[1].resolve({})
    assert.equal((await second).status, 200)
    assert.equal((await manager.input(entry, one)).status, 502)
    assert.equal(waiting.length, 2)
  } finally { manager.close() }
})

test('writer sequence dedup stays bounded for unlimited writes and rejects old or skipped input', async () => {
  const client = new Client(), manager = new CodexTerminal(client)
  try {
    const start = await manager.start('task', newTerminal()), entry = manager.get('task', start.body.terminalId)
    const writerId = randomUUID()
    for (let sequence = 0; sequence < 9000; sequence++) { assert.equal((await manager.input(entry, { writerId, sequence, deltaBase64: 'YQ==' })).status, 200) }
    assert.equal(entry.writes.size, 1)
    assert.equal(entry.writes.get(writerId).sequence, 8999)
    assert.equal((await manager.input(entry, { writerId, sequence: 8999, deltaBase64: 'YQ==' })).status, 200)
    assert.equal((await manager.input(entry, { writerId, sequence: 0, deltaBase64: 'YQ==' })).status, 409)
    assert.equal((await manager.input(entry, { writerId, sequence: 9001, deltaBase64: 'YQ==' })).status, 409)
    assert.equal(client.calls.filter(call => call.method === 'command/exec/write').length, 9000)
  } finally { manager.close() }
})

test('long native exec requests have no RPC timer while ordinary requests retain their timeout', async () => {
  const { default: CodexClient } = await import('../src/Codex/CodexClient.js')
  const client = new CodexClient({ timeout: 10 })
  client.process = { stdin: { destroyed: false, write() {} }, kill() {} }
  const execution = client.send('command/exec', { processId: 'terminal' }, client.process, null)
  await assert.rejects(client.send('ordinary/read', {}), /timed out/)
  assert.equal(client.pending.size, 1)
  assert.equal(client.pending.get(1).timer, null)
  client.receive({ id: 1, result: { exitCode: 0, stdout: '', stderr: '' } })
  assert.equal((await execution).exitCode, 0)
  client.close()
})

test('disconnect during terminal preflight does not start a process on a replacement connection', async () => {
  const client = new Client(), manager = new CodexTerminal(client)
  try {
    let resolveAccount
    const native = client.request.bind(client)
    client.request = (method, params, timeout) => method === 'account/read' ? new Promise(resolve => { resolveAccount = resolve }) : native(method, params, timeout)
    const starting = manager.start('task', newTerminal())
    client.emit('disconnected')
    resolveAccount({ account: { type: 'chatgpt' } })
    assert.equal((await starting).status, 502)
    assert.equal(client.executions.size, 0)
  } finally { manager.close() }
})


test('quiet reconnect receives a non-sequenced readiness snapshot after replay, including ended terminals', async () => {
  const client = new Client(), manager = new CodexTerminal(client)
  try {
    const start = await manager.start('task', newTerminal()), entry = manager.get('task', start.body.terminalId)
    const seq = entry.seq, response = new Response()
    manager.subscribe(entry, seq, response)
    assert.deepEqual(response.events(), JSON.parse(JSON.stringify([{ type: 'terminal_ready', ...manager.snapshot(entry) }])))
    assert.equal(entry.seq, seq)
    assert.equal(response.events()[0].seq, undefined)
    response.end()
    client.executions.get(entry.terminalId).resolve({ exitCode: 0 })
    await new Promise(resolve => setImmediate(resolve))
    const ended = new Response()
    manager.subscribe(entry, -1, ended)
    assert.equal(ended.events().at(-1).type, 'terminal_ready')
    assert.equal(ended.events().at(-1).status, 'exited')
    assert.equal(ended.events().at(-1).seq, undefined)
    assert.equal(ended.ended, true)
  } finally { manager.close() }
})
