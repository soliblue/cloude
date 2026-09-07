import test, { after } from 'node:test'
import assert from 'node:assert/strict'
import { EventEmitter, once } from 'node:events'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
const isolatedData = fs.mkdtempSync(path.join(os.tmpdir(), 'cloude-unit-data-'))
process.env.CLOUDE_DATA = isolatedData
after(() => fs.rmSync(isolatedData, { recursive: true, force: true }))
const { default: CodexRunner } = await import('../src/Codex/CodexRunner.js')
import CodexSessions from '../src/Codex/CodexSessions.js'
import CodexClient from '../src/Codex/CodexClient.js'
import { normalizedNotification } from '../src/Codex/CodexEvent.js'

class FakeClient extends EventEmitter {
  constructor() {
    super()
    this.calls = []
    this.responses = []
  }

  async request(method, params) {
    this.calls.push({ method, params })
    if (method === 'account/read') { return { account: { type: 'chatgpt' } } }
    if (method === 'config/read') { return { config: {} } }
    if (method === 'account/rateLimits/read') { return { rateLimits: { primary: { usedPercent: 0 } } } }
    if (method === 'review/start') { return { turn: { id: 'turn-1' }, reviewThreadId: 'thread-1' } }
    return method === 'turn/start' ? { turn: { id: 'turn-1' } } : { thread: { id: 'thread-1' }, model: 'test-model', modelProvider: 'openai' }
  }

  respond(id, result) {
    this.responses.push({ id, result })
  }
}

class FakeResponse extends EventEmitter {
  constructor() {
    super()
    this.chunks = []
    this.writableLength = 0
  }

  write(data) { this.chunks.push(data.toString()) }
  end(data) { if (data) { this.write(data) }; this.ended = true; this.emit('finish') }
  get events() { return this.chunks.join('').trim().split('\n').filter(Boolean).map((line) => JSON.parse(line)) }
}

test('Codex uses thread lifecycle, preserves native images, and durably replays completed tools and text', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-test-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const sessions = new CodexSessions(directory)
  const client = new FakeClient()
  const runner = new CodexRunner({ sessionId: 'SESSION-A', model: 'test-model', effort: 'high', skills: [{ name: 'review', path: '/skills/review/SKILL.md' }], mentions: [{ name: 'README', path: '/project/README.md' }], projectId: 'project-1' }, client, sessions)
  const response = new FakeResponse()
  runner.subscribe(response)
  await runner.begin(directory, 'hello', [{ data: 'aGVsbG8=', mediaType: 'image/png' }])
  assert.equal(client.calls.find((call) => call.method === 'thread/start').params.sandbox, 'workspace-write')
  assert.equal(client.calls.find((call) => call.method === 'thread/start').params.approvalPolicy, 'on-request')
  assert.equal(client.calls.find((call) => call.method === 'turn/start').params.input[1].type, 'skill')
  assert.equal(client.calls.find((call) => call.method === 'turn/start').params.input[2].type, 'mention')
  assert.equal(client.calls.find((call) => call.method === 'turn/start').params.input[3].type, 'image')
  assert.equal(client.calls.find((call) => call.method === 'thread/start').params.projectId, 'project-1')
  assert.equal(client.calls.find((call) => call.method === 'turn/start').params.effort, 'high')
  assert.equal(sessions.read('session-a').threadId, 'thread-1')
  client.emit('notification', { method: 'item/agentMessage/delta', params: { threadId: 'other-thread', delta: 'wrong' } })
  client.emit('notification', { method: 'item/agentMessage/delta', params: { threadId: 'thread-1', delta: 'hello' } })
  client.emit('notification', { method: 'item/started', params: { threadId: 'thread-1', item: { type: 'commandExecution', id: 'command-1', command: 'pwd', cwd: directory } } })
  client.emit('notification', { method: 'item/completed', params: { threadId: 'thread-1', item: { type: 'commandExecution', id: 'command-1', command: 'pwd', aggregatedOutput: directory, exitCode: 0 } } })
  client.emit('notification', { method: 'turn/completed', params: { threadId: 'thread-1', turn: { id: 'turn-1', status: 'completed' } } })
  assert.equal(response.ended, true)
  assert.ok(!response.chunks.join('').includes('wrong'))
  assert.ok(response.events.some((event) => event.event?.message?.content?.[0]?.name === 'Bash'))
  assert.ok(response.events.some((event) => event.event?.message?.content?.[0]?.tool_use_id === 'command-1'))
  assert.equal(client.listenerCount('notification'), 0)
  const replay = new FakeResponse()
  const replayFinished = once(replay, 'finish')
  assert.equal(new CodexSessions(directory).replay('SESSION-A', replay), true)
  await replayFinished
  assert.deepEqual(replay.events.slice(1), response.events)
  assert.equal(replay.events[0].type, 'replay')
  const resumed = new CodexRunner({ sessionId: 'SESSION-A' }, client, sessions)
  await resumed.begin(directory, 'continue', [])
  assert.ok(client.calls.some((call) => call.method === 'thread/resume'))
  resumed.finish(0)
})

test('requests preserve server IDs, reject stale replies, steer and interrupt exact active turn', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-test-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const client = new FakeClient()
  const runner = new CodexRunner({ sessionId: 'approval-session', permissionMode: 'plan' }, client, new CodexSessions(directory))
  await runner.begin(directory, 'hello', [])
  assert.equal(client.calls.find((call) => call.method === 'thread/start').params.sandbox, 'read-only')
  assert.equal(client.calls.find((call) => call.method === 'turn/start').params.collaborationMode.mode, 'plan')
  client.emit('request', { id: 44, method: 'item/commandExecution/requestApproval', params: { threadId: 'thread-1', command: 'ls' } })
  assert.equal(runner.respond('44', { decision: 'decline' }), true)
  assert.equal(runner.respond('44', { decision: 'accept' }), false)
  assert.deepEqual(client.responses, [{ id: 44, result: { decision: 'decline' } }])
  client.emit('request', { id: 45, method: 'item/permissions/requestApproval', params: { threadId: 'thread-1', permissions: { network: { enabled: true } } } })
  runner.respond('45', { decision: 'accept' })
  assert.deepEqual(client.responses.at(-1), { id: 45, result: { permissions: { network: { enabled: true } }, scope: 'turn' } })
  await runner.steer('focus on tests')
  assert.equal(client.calls.at(-1).params.expectedTurnId, 'turn-1')
  runner.abort()
  assert.deepEqual(client.calls.at(-1), { method: 'turn/interrupt', params: { threadId: 'thread-1', turnId: 'turn-1' } })
  runner.finish(0)
})

test('normalization preserves web search, agent details, reasoning, and failed command state', () => {
  assert.equal(normalizedNotification('item/started', { item: { type: 'webSearch', id: 'w', query: 'Codex' } })[0].message.content[0].name, 'WebSearch')
  assert.equal(normalizedNotification('item/started', { item: { type: 'collabAgentToolCall', id: 'a', receiverThreadIds: ['child'] } })[0].message.content[0].input.receiverThreadIds[0], 'child')
  assert.equal(normalizedNotification('item/reasoning/summaryTextDelta', { delta: 'Thinking' })[0].event.delta.thinking, 'Thinking')
  assert.equal(normalizedNotification('item/completed', { item: { type: 'commandExecution', id: 'c', exitCode: 1 } })[0].message.content[0].is_error, true)
})

test('JSON RPC matches out of order responses and propagates server errors', async () => {
  const client = new CodexClient({ timeout: 500 })
  client.process = { stdin: { write() {} } }
  const first = client.send('one', {})
  const second = client.send('two', {})
  client.receive({ id: 2, result: { value: 2 } })
  client.receive({ id: 1, result: { value: 1 } })
  assert.deepEqual(await Promise.all([first, second]), [{ value: 1 }, { value: 2 }])
  const failure = client.send('failure', {})
  client.receive({ id: 3, error: { message: 'login required' } })
  await assert.rejects(failure, /login required/)
  assert.equal(client.pending.size, 0)
})

test('API-key authentication cannot start a billed turn', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-test-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const client = new FakeClient()
  client.request = async () => ({ account: { type: 'apiKey' } })
  const runner = new CodexRunner({ sessionId: 'api-key-test' }, client, new CodexSessions(directory))
  await assert.rejects(runner.begin(directory, 'hello', []), /API key billing is not supported/)
  runner.finish(1)
})

test('reconnect recovers events beyond the in-memory ring without duplicates', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-test-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const runner = new CodexRunner({ sessionId: 'long-turn' }, new FakeClient(), new CodexSessions(directory))
  for (let index = 0; index < 1100; index += 1) { runner.emit({ type: 'test', value: index }) }
  const response = new FakeResponse()
  await runner.subscribe(response, 5)
  assert.equal(response.events.length, 1095)
  assert.equal(response.events[0].seq, 6)
  runner.emit({ type: 'test', value: 1100 })
  assert.equal(response.events.length, 1096)
  assert.equal(new Set(response.events.map((event) => event.seq)).size, 1096)
  runner.finish(0)
})

test('daemon restart closes an orphaned journal with a recoverable interruption', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-test-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const sessions = new CodexSessions(directory)
  sessions.reset('orphan')
  sessions.append('orphan', `${JSON.stringify({ type: 'heartbeat', seq: 7, sessionId: 'orphan' })}\n`)
  const response = new FakeResponse()
  const finished = once(response, 'finish')
  sessions.replay('orphan', response)
  await finished
  assert.equal(response.events.at(-2).type, 'error')
  assert.equal(response.events.at(-1).code, 1)
  assert.equal(response.events.at(-1).seq, 9)
})

test('app-server process initializes once, rejects malformed output and reconnects without stale process races', async (t) => {
  const client = new CodexClient({ executable: process.execPath, args: ['--input-type=module', '-e', `
    import { createInterface } from 'node:readline'
    let initialized = 0
    createInterface({ input: process.stdin }).on('line', (line) => {
      const message = JSON.parse(line)
      if (message.method === 'initialize') { initialized += 1 }
      if (message.method === 'malformed') { process.stdout.write('invalid protocol\\n') }
      else if (message.id !== undefined) { process.stdout.write(JSON.stringify({ id: message.id, result: { initialized, value: message.params.value } }) + '\\n') }
    })
  `], timeout: 2000 })
  t.after(() => client.close())
  assert.deepEqual(await Promise.all([client.request('echo', { value: 1 }), client.request('echo', { value: 2 })]), [{ initialized: 1, value: 1 }, { initialized: 1, value: 2 }])
  await assert.rejects(client.request('malformed'), /invalid protocol/)
  assert.deepEqual(await client.request('echo', { value: 3 }), { initialized: 1, value: 3 })
})

test('normalized notifications are emitted once while unknown methods and turn start remain replayable', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-wire-test-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const runner = new CodexRunner({ sessionId: 'wire-contract', threadId: 'thread-1' }, new FakeClient(), new CodexSessions(directory))
  const response = new FakeResponse()
  await runner.subscribe(response)
  runner.receive({ method: 'turn/started', params: { threadId: 'thread-1', turn: { id: 'turn-1' } } })
  runner.receive({ method: 'item/started', params: { threadId: 'thread-1', item: { id: 'user', type: 'userMessage' } } })
  runner.receive({ method: 'item/agentMessage/delta', params: { threadId: 'thread-1', delta: 'Hello' } })
  runner.receive({ method: 'item/reasoning/summaryTextDelta', params: { threadId: 'thread-1', delta: 'Reasoning' } })
  runner.receive({ method: 'item/commandExecution/outputDelta', params: { threadId: 'thread-1', itemId: 'command', delta: 'output' } })
  runner.receive({ method: 'thread/tokenUsage/updated', params: { threadId: 'thread-1', tokenUsage: { last: { totalTokens: 20 } } } })
  runner.receive({ method: 'future/event', params: { threadId: 'thread-1', novel: { preserved: true } } })
  runner.receive({ method: 'turn/completed', params: { threadId: 'thread-1', turn: { id: 'turn-1', status: 'completed' } } })
  assert.deepEqual(response.events.filter((event) => event.codex).map((event) => event.codex.method), ['turn/started', 'future/event'])
  assert.equal(response.events.find((event) => event.codex?.method === 'future/event').codex.params.novel.preserved, true)
  assert.equal(response.events.filter((event) => event.event?.event?.delta?.text === 'Hello').length, 1)
  assert.equal(response.events.filter((event) => event.event?.event?.delta?.thinking === 'Reasoning').length, 1)
  assert.equal(response.events.filter((event) => event.type === 'tool_output_delta').length, 1)
  assert.equal(response.events.filter((event) => event.type === 'usage').length, 1)
  assert.equal(response.events.filter((event) => event.event?.type === 'result').length, 1)
  assert.deepEqual(response.events.map((event) => event.seq), response.events.map((_, index) => index + 1))
  const replay = new FakeResponse()
  const completed = once(replay, 'finish')
  runner.sessions.replay('wire-contract', replay)
  await completed
  assert.deepEqual(replay.events.slice(1), response.events)
})


test('inline review uses the normal live approvals, interruption and durable replay pipeline', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-review-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const sessions = new CodexSessions(directory)
  const client = new FakeClient()
  const original = client.request.bind(client)
  client.request = async (method, params) => {
    const result = await original(method, params)
    if (method === 'review/start') {
      client.emit('notification', { method: 'turn/started', params: { threadId: 'thread-1', turn: { id: 'turn-1' } } })
      client.emit('notification', { method: 'item/started', params: { threadId: 'thread-1', item: { id: 'entered', type: 'enteredReviewMode', review: 'Review local changes' } } })
      client.emit('notification', { method: 'item/completed', params: { threadId: 'thread-1', item: { id: 'entered', type: 'enteredReviewMode', review: 'Review local changes' } } })
      client.emit('notification', { method: 'item/agentMessage/delta', params: { threadId: 'thread-1', delta: 'Checking files' } })
    }
    return result
  }
  const runner = new CodexRunner({ sessionId: 'review-session', reviewTarget: { type: 'baseBranch', branch: 'main' } }, client, sessions)
  t.after(() => runner.finish(0))
  const response = new FakeResponse()
  runner.subscribe(response)
  await runner.begin(directory, 'Review against main', [])
  assert.deepEqual(client.calls.find((call) => call.method === 'review/start').params, { threadId: 'thread-1', target: { type: 'baseBranch', branch: 'main' }, delivery: 'inline' })
  assert.equal(client.calls.filter((call) => call.method === 'turn/start').length, 0)
  assert.equal(response.events.filter((event) => event.state === 'reviewing').length, 1)
  assert.ok(response.events.some((event) => event.event?.event?.delta?.text === 'Checking files'))
  client.emit('request', { id: 91, method: 'item/commandExecution/requestApproval', params: { threadId: 'thread-1', command: 'git diff' } })
  assert.equal(runner.respond('91', { decision: 'accept' }), true)
  assert.deepEqual(client.responses, [{ id: 91, result: { decision: 'accept' } }])
  runner.abort()
  assert.deepEqual(client.calls.find((call) => call.method === 'turn/interrupt').params, { threadId: 'thread-1', turnId: 'turn-1' })
  client.emit('notification', { method: 'item/completed', params: { threadId: 'thread-1', item: { id: 'exited', type: 'exitedReviewMode', review: 'Found a concrete regression.' } } })
  client.emit('notification', { method: 'turn/completed', params: { threadId: 'thread-1', turn: { id: 'turn-1', status: 'interrupted' } } })
  assert.ok(response.events.some((event) => event.type === 'aborted'))
  assert.ok(response.events.some((event) => event.event?.message?.content?.[0]?.text === 'Found a concrete regression.'))
  assert.equal(response.events.filter((event) => event.state === 'review_complete').length, 1)
  const replay = new FakeResponse()
  const done = once(replay, 'finish')
  assert.equal(new CodexSessions(directory).replay('review-session', replay), true)
  await done
  assert.deepEqual(replay.events.slice(1), response.events)
})

test('review exit text is preserved when standalone and not duplicated after matching assistant output', async (t) => {
  for (const previous of ['none', 'delta', 'final']) {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-review-text-'))
    t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
    const client = new FakeClient()
    const runner = new CodexRunner({ sessionId: 'review', reviewTarget: { type: 'uncommittedChanges' } }, client, new CodexSessions(directory))
    await runner.begin(directory, 'Review', [])
    if (previous === 'delta') client.emit('notification', { method: 'item/agentMessage/delta', params: { threadId: 'thread-1', delta: 'Review result' } })
    if (previous === 'final') client.emit('notification', { method: 'item/completed', params: { threadId: 'thread-1', item: { id: 'assistant', type: 'agentMessage', text: 'Review result' } } })
    client.emit('notification', { method: 'item/completed', params: { threadId: 'thread-1', item: { id: 'review-end', type: 'exitedReviewMode', review: 'Review result' } } })
    runner.finish(0)
    const content = runner.ring.map((item) => JSON.parse(item.data))
    assert.equal(content.filter((event) => event.event?.message?.content?.[0]?.text === 'Review result').length, previous === 'delta' ? 0 : 1)
    assert.equal(content.filter((event) => event.event?.message?.content?.[0]?.name === 'exitedReviewMode').length, 0)
  }
})

test('review targets reject malformed or Claude requests before any native inference', async (t) => {
  const { validReviewTarget } = await import('../src/Codex/CodexReviewTarget.js')
  const { start } = await import('../src/Handlers/ChatHandler.js')
  const invalid = [null, [], {}, { type: 'unknown' }, { type: 'uncommittedChanges', instruction: 'extra' }, { type: 'baseBranch', branch: '--force' }, { type: 'baseBranch', branch: 'HEAD~1' }, { type: 'commit', sha: '--output=x' }, { type: 'commit', sha: 'abcd', title: 12 }, { type: 'custom', instructions: ' ' }, { type: 'custom', instructions: 'a'.repeat(16001) }]
  for (const target of invalid) {
    assert.equal(validReviewTarget(target), false)
    assert.equal(start({ body: Buffer.from(JSON.stringify({ provider: 'codex', path: '/project', prompt: 'Review', reviewTarget: target })) }, { id: 'invalid-review' }).status, 400)
  }
  assert.equal(start({ body: Buffer.from(JSON.stringify({ provider: 'claude', path: '/project', prompt: 'Review', reviewTarget: { type: 'uncommittedChanges' } })) }, { id: 'invalid-review' }).status, 400)
  for (const target of [{ type: 'uncommittedChanges' }, { type: 'baseBranch', branch: 'codex/review' }, { type: 'commit', sha: 'abcd1234', title: 'Commit' }, { type: 'custom', instructions: 'Review concurrency\nand persistence.' }]) assert.equal(validReviewTarget(target), true)
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-review-invalid-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const client = new FakeClient()
  const runner = new CodexRunner({ sessionId: 'invalid', reviewTarget: { type: 'invalid' } }, client, new CodexSessions(directory))
  await assert.rejects(runner.begin(directory, 'Review', []), /Invalid Codex review target/)
  runner.finish(1)
  assert.equal(client.calls.length, 0)
})

test('failed initialization releases the child and retries a fresh connection', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-initialize-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  for (const mode of ['timeout', 'reject']) {
    const marker = path.join(directory, mode)
    const client = new CodexClient({ executable: process.execPath, timeout: 250, args: ['--input-type=module', '-e', `
      import fs from 'node:fs'
      import { createInterface } from 'node:readline'
      const first = !fs.existsSync(${JSON.stringify(marker)})
      fs.writeFileSync(${JSON.stringify(marker)}, '')
      createInterface({ input: process.stdin }).on('line', line => {
        const message = JSON.parse(line)
        if (message.id === undefined) return
        if (first && message.method === 'initialize') {
          if (${JSON.stringify(mode)} === 'reject') process.stdout.write(JSON.stringify({id:message.id,error:{message:'initialization rejected'}})+'\\n')
        } else process.stdout.write(JSON.stringify({id:message.id,result:{ok:true}})+'\\n')
      })
    `] })
    t.after(() => client.close())
    const first = client.request('echo')
    const child = client.process
    await assert.rejects(first, /timed out|initialization rejected/)
    assert.equal(client.process, null)
    assert.equal(client.ready, null)
    assert.equal(child.killed, true)
    assert.equal(client.pending.size, 0)
    assert.deepEqual(await client.request('echo'), { ok: true })
    client.disconnect(new Error('late old process failure'), child)
    assert.deepEqual(await client.request('echo'), { ok: true })
    client.close()
  }
})

test('synchronous transport write failure clears pending requests and closes only owned child', async () => {
  const client = new CodexClient()
  let killed = 0
  client.process = { stdin: { write() { throw new Error('broken pipe') } }, kill() { killed += 1 } }
  await assert.rejects(client.send('test', {}), /broken pipe/)
  assert.equal(client.pending.size, 0)
  assert.equal(client.process, null)
  assert.equal(killed, 1)
  await assert.rejects(client.send('test', {}), /disconnected/)
})

test('journal failure stops only its task before undurable output reaches subscribers', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-journal-failure-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const client = new FakeClient()
  const sessions = new CodexSessions(directory)
  const runner = new CodexRunner({ sessionId: 'broken-journal', threadId: 'thread-1' }, client, sessions)
  const other = new CodexRunner({ sessionId: 'healthy-journal', threadId: 'thread-2' }, client, new CodexSessions(directory))
  t.after(() => other.finish(0))
  const response = new FakeResponse()
  await runner.subscribe(response)
  runner.turnId = 'turn-1'
  runner.emit({ type: 'heartbeat' })
  sessions.append = () => { throw new Error('ENOSPC secret path') }
  assert.doesNotThrow(() => client.emit('notification', { method: 'item/agentMessage/delta', params: { threadId: 'thread-1', delta: 'not durable' } }))
  assert.equal(runner.hasExited, true)
  assert.equal(other.hasExited, false)
  assert.equal(client.listenerCount('notification'), 1)
  assert.deepEqual(response.events.map(event => event.seq), [1, 2, 3])
  assert.deepEqual(response.events.map(event => event.type), ['heartbeat', 'error', 'exit'])
  assert.ok(!response.chunks.join('').includes('not durable'))
  assert.ok(!response.chunks.join('').includes('secret path'))
  assert.deepEqual(client.calls.at(-1), { method: 'turn/interrupt', params: { threadId: 'thread-1', turnId: 'turn-1' } })
})

test('journal constructor and initialization failures cannot leak listeners or start a turn', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-journal-init-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const client = new FakeClient()
  const sessions = new CodexSessions(directory)
  sessions.reset = () => { throw new Error('storage unavailable') }
  assert.throws(() => new CodexRunner({ sessionId: 'failed-constructor' }, client, sessions), /storage unavailable/)
  assert.equal(client.listenerCount('notification'), 0)
  assert.equal(client.listenerCount('request'), 0)
  assert.equal(client.listenerCount('disconnected'), 0)
  const failing = new CodexSessions(directory)
  failing.append = () => { throw new Error('storage unavailable') }
  const runner = new CodexRunner({ sessionId: 'failed-initialize' }, client, failing)
  await runner.begin(directory, 'must not run', [])
  assert.equal(client.calls.some(call => call.method === 'turn/start'), false)
  assert.equal(runner.hasExited, true)
  assert.equal(client.listenerCount('notification'), 0)
})

test('journal failure while completing emits one failed exit and finishes once', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-journal-exit-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const sessions = new CodexSessions(directory)
  let finishes = 0
  const runner = new CodexRunner({ sessionId: 'failed-exit', onFinish() { finishes += 1 } }, new FakeClient(), sessions)
  const response = new FakeResponse()
  await runner.subscribe(response)
  sessions.append = () => { throw new Error('storage unavailable') }
  runner.finish(0)
  assert.equal(finishes, 1)
  assert.equal(runner.exitCode, 1)
  assert.deepEqual(response.events.map(event => event.type), ['error', 'exit'])
  assert.deepEqual(response.events.map(event => event.seq), [1, 2])
})

test('real review report-first ordering emits the identical later assistant report once', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-review-report-first-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const runner = new CodexRunner({ sessionId: 'report-first', threadId: 'thread-1', reviewTarget: { type: 'uncommittedChanges' } }, new FakeClient(), new CodexSessions(directory))
  const response = new FakeResponse()
  await runner.subscribe(response)
  for (const event of JSON.parse(fs.readFileSync(new URL('./fixtures/review-report-first.json', import.meta.url), 'utf8'))) { runner.receive(event) }
  runner.finish(0)
  assert.equal(response.events.filter(event => event.event?.message?.content?.some(content => content.type === 'text')).length, 1)
})

test('shell commands adopt asynchronous turn IDs, cancel after late starts, and never invoke a model', async (t) => {
  for (const early of [false, true]) {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-shell-'))
    t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
    const client = new FakeClient()
    const original = client.request.bind(client)
    client.request = async (method, params) => {
      if (method === 'thread/shellCommand') {
        client.calls.push({ method, params })
        if (early) client.emit('notification', { method: 'turn/started', params: { threadId: 'thread-1', turn: { id: 'shell-turn' } } })
        return {}
      }
      return original(method, params)
    }
    const sessions = new CodexSessions(directory)
    const runner = new CodexRunner({ sessionId: 'shell', shellCommand: 'pwd' }, client, sessions)
    const response = new FakeResponse()
    await runner.subscribe(response)
    await runner.begin(directory, 'Run command', [])
    assert.equal(response.events.some(event => event.event?.subtype === 'init'), false)
    runner.abort()
    if (!early) client.emit('notification', { method: 'turn/started', params: { threadId: 'thread-1', turn: { id: 'shell-turn' } } })
    assert.equal(client.calls.filter(call => call.method === 'turn/interrupt').length, 1)
    assert.deepEqual(client.calls.find(call => call.method === 'turn/interrupt').params, { threadId: 'thread-1', turnId: 'shell-turn' })
    assert.deepEqual(client.calls.find(call => call.method === 'thread/shellCommand').params, { threadId: 'thread-1', command: 'pwd' })
    assert.equal(client.calls.some(call => ['turn/start', 'review/start', 'account/rateLimits/read'].includes(call.method)), false)
    client.emit('notification', { method: 'item/started', params: { threadId: 'thread-1', item: { type: 'commandExecution', source: 'userShell', id: 'shell-tool', command: 'pwd', cwd: directory } } })
    client.emit('notification', { method: 'item/commandExecution/outputDelta', params: { threadId: 'thread-1', itemId: 'shell-tool', delta: directory } })
    client.emit('notification', { method: 'turn/completed', params: { threadId: 'thread-1', turn: { id: 'shell-turn', status: 'interrupted' } } })
    assert.ok(response.events.some(event => event.type === 'tool_output_delta' && event.text === directory))
    const replay = new FakeResponse()
    const finished = once(replay, 'finish')
    sessions.replay('shell', replay)
    await finished
    assert.deepEqual(replay.events.slice(1), response.events)
    const retry = new CodexRunner({ sessionId: 'shell', shellCommand: 'pwd' }, client, sessions)
    await retry.begin(directory, 'Run command', [])
    assert.ok(client.calls.some(call => call.method === 'thread/resume'))
    retry.finish(0)
  }
})

test('shell input rejects mixed modes and non-Codex providers before native calls', async (t) => {
  const { start } = await import('../src/Handlers/ChatHandler.js')
  const invalid = [{shellCommand:null},{shellCommand:''},{shellCommand:' '},{shellCommand:1},{shellCommand:'a'.repeat(16385)},{shellCommand:'pwd',provider:'claude'},{shellCommand:'pwd',reviewTarget:{type:'uncommittedChanges'}},{shellCommand:'pwd',images:[{data:'x'}]},{shellCommand:'pwd',skills:[{name:'skill',path:'/skill'}]},{shellCommand:'pwd',mentions:[{name:'file',path:'/file'}]}]
  for (const value of invalid) assert.equal(start({body:Buffer.from(JSON.stringify({provider:'codex',path:'/tmp',prompt:'Run command',...value}))},{id:'invalid-shell'}).status,400)
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-shell-invalid-'))
  t.after(() => fs.rmSync(directory, { recursive:true, force:true }))
  const client = new FakeClient()
  const runner = new CodexRunner({sessionId:'invalid-shell',shellCommand:'pwd',skills:[{name:'skill',path:'/skill'}]}, client, new CodexSessions(directory))
  await assert.rejects(runner.begin(directory,'Run command',[]),/Invalid Codex shell command/)
  assert.equal(client.calls.length,0)
  runner.finish(1)
})

test('unopened child approvals are captured globally, scoped to imported tasks, and preserve typed wire IDs', async (t) => {
  const { codexClient } = await import('../src/Codex/CodexClient.js')
  const { codexSessions } = await import('../src/Codex/CodexSessions.js')
  const { requests, respond } = await import('../src/Handlers/CodexHandler.js')
  const wire = []
  codexClient.process = { stdin: { write(value) { wire.push(JSON.parse(value)) } }, kill() {} }
  t.after(() => codexClient.close())
  codexClient.receive({ id: 44, method: 'item/commandExecution/requestApproval', params: { threadId: 'unopened-child', command: 'pwd' } })
  assert.equal(codexClient.requestsForThread('unopened-child').length, 1)
  codexSessions.write('imported-child', { threadId: 'unopened-child', provider: 'codex' })
  const snapshot = JSON.parse(requests({}, { id: 'imported-child' }).body).requests
  assert.equal(snapshot.length, 1)
  assert.notEqual(snapshot[0].requestId, '44')
  const req = { json: () => ({ requestId: snapshot[0].requestId, result: { decision: 'accept' } }) }
  assert.equal(respond(req, { id: 'other-child' }).status, 409)
  assert.equal(wire.length, 0)
  assert.equal(respond(req, { id: 'imported-child' }).status, 200)
  assert.deepEqual(wire, [{ id: 44, result: { decision: 'accept' } }])
  assert.equal(respond(req, { id: 'imported-child' }).status, 409)
  assert.equal(JSON.parse(requests({}, { id: 'imported-child' }).body).requests.length, 0)
  codexClient.receive({ id: '45', method: 'item/permissions/requestApproval', params: { threadId: 'unopened-child', permissions: { network: { enabled: true } } } })
  const permission = codexClient.requestsForThread('unopened-child')[0]
  assert.equal(codexClient.respond(permission.requestKey, { decision: 'acceptForSession' }, 'unopened-child'), true)
  assert.deepEqual(wire.at(-1), { id: '45', result: { permissions: { network: { enabled: true } }, scope: 'session' } })
})

test('server resolution and disconnect clear global approvals without stale ID reuse or cross-thread resolution', () => {
  const client = new CodexClient()
  client.process = { stdin: { write() {} }, kill() {} }
  client.receive({ id: 1, method: 'item/commandExecution/requestApproval', params: { threadId: 'child' } })
  const old = client.requestsForThread('child')[0].requestKey
  client.receive({ method: 'serverRequest/resolved', params: { threadId: 'other', requestId: 1 } })
  assert.equal(client.requestsForThread('child').length, 1)
  client.receive({ method: 'serverRequest/resolved', params: { threadId: 'child', requestId: 1 } })
  assert.equal(client.requestsForThread('child').length, 0)
  client.receive({ id: 2, method: 'item/commandExecution/requestApproval', params: { threadId: 'child' } })
  client.close()
  assert.equal(client.serverRequests.size, 0)
  const newClient = new CodexClient()
  newClient.process = { stdin: { write() {} }, kill() {} }
  newClient.receive({ id: 1, method: 'item/commandExecution/requestApproval', params: { threadId: 'child' } })
  assert.notEqual(newClient.requestsForThread('child')[0].requestKey, old)
  assert.equal(newClient.respond(old, { decision: 'accept' }, 'child'), false)
  newClient.close()
})

test('owned task and global registry resolve one live approval card with the same opaque ID', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-global-owned-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const client = new CodexClient()
  client.process = { stdin: { write() {} }, kill() {} }
  const runner = new CodexRunner({sessionId:'owned',threadId:'thread-owned'},client,new CodexSessions(directory))
  const response = new FakeResponse()
  await runner.subscribe(response)
  client.receive({id:77,method:'item/commandExecution/requestApproval',params:{threadId:'thread-owned'}})
  const key = client.requestsForThread('thread-owned')[0].requestKey
  assert.equal(response.events.find(event => event.type === 'request').requestId,key)
  assert.equal(runner.respond(key,{decision:'decline'}),true)
  client.receive({method:'serverRequest/resolved',params:{threadId:'thread-owned',requestId:77}})
  assert.equal(response.events.filter(event=>event.type==='request_resolved').length,1)
  assert.equal(runner.requests.size,0)
  runner.finish(0)
  client.close()
})

test('helper attention routes one push to the nearest owned ancestor and clears on resolution', async (t) => {
  const { pushDelivery } = await import('../src/Notifications/PushDelivery.js')
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-child-attention-'))
  t.after(() => fs.rmSync(directory, {recursive:true,force:true}))
  const enqueued = []
  const cancelled = []
  const enqueue = pushDelivery.enqueue
  const cancel = pushDelivery.cancel
  pushDelivery.enqueue = (...args) => { enqueued.push(args); return true }
  pushDelivery.cancel = key => cancelled.push(key)
  t.after(() => {pushDelivery.enqueue=enqueue;pushDelivery.cancel=cancel})
  const client = new CodexClient()
  client.process = {stdin:{write(){}},kill(){}}
  const runner = new CodexRunner({sessionId:'parent-phone-session',threadId:'parent-thread'},client,new CodexSessions(directory))
  const response = new FakeResponse()
  await runner.subscribe(response)
  client.receive({method:'thread/started',params:{thread:{id:'child-thread',source:{subAgent:{thread_spawn:{parent_thread_id:'parent-thread',depth:1}}}}}})
  client.receive({method:'thread/started',params:{thread:{id:'grandchild-thread',parentThreadId:'child-thread'}}})
  client.receive({id:1,method:'item/commandExecution/requestApproval',params:{threadId:'grandchild-thread',command:'pwd'}})
  const key=client.requestsForThread('grandchild-thread')[0].requestKey
  assert.equal(enqueued.length,1)
  assert.equal(enqueued[0][3].sessionId,'parent-phone-session')
  assert.equal(enqueued[0][3].kind,'attention')
  assert.deepEqual(response.events.filter(e=>e.type==='agent_attention').map(({threadId,requestId,pending})=>({threadId,requestId,pending})),[{threadId:'grandchild-thread',requestId:key,pending:true}])
  assert.equal(runner.requests.size,0)
  assert.equal(runner.respond(key,{decision:'accept'}),false)
  client.receive({method:'serverRequest/resolved',params:{threadId:'grandchild-thread',requestId:1}})
  assert.ok(cancelled.includes(enqueued[0][0]))
  assert.equal(response.events.at(-1).pending,false)
  client.receive({id:2,method:'item/commandExecution/requestApproval',params:{threadId:'parent-thread',command:'pwd'}})
  assert.equal(enqueued.length,2)
  assert.equal(enqueued[1][0],'attention:parent-phone-session')
  runner.finish(0)
  client.close()
})

test('late parent discovery recovers child attention and lifecycle clears semantic notifications', async (t) => {
  const { pushDelivery } = await import('../src/Notifications/PushDelivery.js')
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'codex-child-late-'))
  t.after(()=>fs.rmSync(directory,{recursive:true,force:true}))
  const enqueue=pushDelivery.enqueue
  const cancel=pushDelivery.cancel
  const pushes=[]
  const canceled=[]
  pushDelivery.enqueue=(...args)=>{pushes.push(args);return true}
  pushDelivery.cancel=key=>canceled.push(key)
  t.after(()=>{pushDelivery.enqueue=enqueue;pushDelivery.cancel=cancel})
  const client=new CodexClient()
  client.process={stdin:{write(){}},kill(){}}
  const runner=new CodexRunner({sessionId:'phone-parent',threadId:'parent'},client,new CodexSessions(directory))
  const response=new FakeResponse()
  await runner.subscribe(response)
  client.receive({id:3,method:'item/commandExecution/requestApproval',params:{threadId:'child'}})
  assert.equal(pushes.length,0)
  client.receive({method:'item/completed',params:{threadId:'parent',item:{id:'spawn',type:'collabAgentToolCall',tool:'spawnAgent',status:'completed',receiverThreadIds:['child']}}})
  assert.equal(pushes.length,1)
  client.receive({method:'item/completed',params:{threadId:'parent',item:{id:'spawn',type:'collabAgentToolCall',tool:'spawnAgent',status:'completed',receiverThreadIds:['child']}}})
  assert.equal(pushes.length,1)
  client.receive({method:'turn/completed',params:{threadId:'child',turn:{id:'child-turn',status:'completed'}}})
  assert.equal(runner.childRequests.size,0)
  assert.ok(canceled.includes(pushes[0][0]))
  client.receive({id:4,method:'item/commandExecution/requestApproval',params:{threadId:'child'}})
  client.close()
  assert.equal(runner.childRequests.size,0)
  assert.ok(canceled.includes(pushes[1][0]))
  assert.equal(response.events.filter(e=>e.type==='agent_attention'&&e.pending===false).length,2)
})

test('nearest child owner takes over attention and parent snapshots recover pending descendants while idle', async (t) => {
  const {codexClient}=await import('../src/Codex/CodexClient.js')
  const {codexSessions}=await import('../src/Codex/CodexSessions.js')
  const {requests}=await import('../src/Handlers/CodexHandler.js')
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'codex-child-owner-'))
  t.after(()=>fs.rmSync(directory,{recursive:true,force:true}))
  codexClient.process={stdin:{write(){}},kill(){}}
  const parent=new CodexRunner({sessionId:'phone-root',threadId:'root'},codexClient,new CodexSessions(directory))
  codexClient.linkParent('child','root')
  codexClient.linkParent('grandchild','child')
  codexClient.receive({id:9,method:'item/commandExecution/requestApproval',params:{threadId:'grandchild'}})
  assert.equal(parent.childRequests.size,1)
  const child=new CodexRunner({sessionId:'phone-child',threadId:'child'},codexClient,new CodexSessions(directory))
  assert.equal(parent.childRequests.size,0)
  assert.equal(child.childRequests.size,1)
  child.finish(0)
  parent.finish(0)
  codexSessions.write('saved-root',{threadId:'root',provider:'codex'})
  const snapshot=JSON.parse(requests({}, {id:'saved-root'}).body)
  assert.equal(snapshot.requests.length,0)
  assert.equal(snapshot.agentAttention.length,1)
  assert.equal(snapshot.agentAttention[0].threadId,'grandchild')
  codexClient.close()
  assert.equal(JSON.parse(requests({}, {id:'saved-root'}).body).agentAttention.length,0)
})

test('resuming without a phone effort override preserves the native saved reasoning effort',async(t)=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'codex-effort-persist-'))
 t.after(()=>fs.rmSync(directory,{recursive:true,force:true}))
 const client=new FakeClient()
 const original=client.request.bind(client)
 client.request=async(method,params)=>{
  const result=await original(method,params)
  return method==='thread/resume'?{...result,reasoningEffort:'high'}:result
 }
 const runner=new CodexRunner({sessionId:'saved-effort',threadId:'thread-1'},client,new CodexSessions(directory))
 await runner.begin(directory,'continue',[])
 assert.equal(client.calls.find(call=>call.method==='turn/start').params.collaborationMode.settings.reasoning_effort,'high')
 runner.finish(0)
})

test('external task closure clears global requests and finishes the live journal once',async(t)=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'codex-task-closed-'))
 t.after(()=>fs.rmSync(directory,{recursive:true,force:true}))
 for(const method of ['thread/closed','thread/archived','thread/deleted']) {
  const client=new CodexClient()
  client.process={stdin:{write(){}},kill(){}}
  const runner=new CodexRunner({sessionId:method,threadId:'closed-thread'},client,new CodexSessions(directory))
  const response=new FakeResponse()
  await runner.subscribe(response)
  client.receive({id:5,method:'item/commandExecution/requestApproval',params:{threadId:'closed-thread'}})
  client.receive({method,params:{threadId:'closed-thread'}})
  assert.equal(client.requestsForThread('closed-thread').length,0)
  assert.equal(runner.hasExited,true)
  assert.equal(response.events.filter(event=>event.type==='exit').length,1)
  assert.equal(response.events.at(-1).code,1)
  assert.equal(client.listenerCount('request'),0)
  client.close()
 }
})

test('closing a task during subscription preflight cannot resume it or start a later turn',async(t)=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'codex-close-preflight-'))
 t.after(()=>fs.rmSync(directory,{recursive:true,force:true}))
 const client=new FakeClient()
 const original=client.request.bind(client)
 let complete
 client.request=(method,params)=>method==='account/read'?new Promise(resolve=>{complete=resolve}):original(method,params)
 const runner=new CodexRunner({sessionId:'closing',threadId:'thread-1'},client,new CodexSessions(directory))
 const pending=runner.begin(directory,'must not start',[])
 runner.receive({method:'thread/closed',params:{threadId:'thread-1'}})
 complete({account:{type:'chatgpt'}})
 await pending
 assert.equal(runner.hasExited,true)
 assert.ok(!client.calls.some(call=>['thread/resume','thread/start','turn/start'].includes(call.method)))
})

test('modern helper activity connects pending child approvals without thread-start notifications',async(t)=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'codex-modern-helper-'))
 t.after(()=>fs.rmSync(directory,{recursive:true,force:true}))
 for(const method of ['item/started','item/completed']) {
  const client=new CodexClient()
  client.process={stdin:{write(){}},kill(){}}
  const runner=new CodexRunner({sessionId:'parent-phone',threadId:'parent-thread'},client,new CodexSessions(directory))
  const response=new FakeResponse()
  await runner.subscribe(response)
  client.receive({id:0,method:'item/commandExecution/requestApproval',params:{threadId:'child-thread'}})
  assert.equal(client.attentionForThread('parent-thread').length,0)
  const fixture=JSON.parse(fs.readFileSync(new URL('./fixtures/modern-helper-started.json',import.meta.url),'utf8'))
  client.receive({...fixture,method})
  assert.equal(client.ownerForThread('child-thread').sessionId,'parent-phone')
  assert.equal(client.attentionForThread('parent-thread').length,1)
  assert.equal(response.events.filter(event=>event.type==='agent_attention'&&event.pending).length,1)
  assert.equal(response.events.find(event=>event.type==='agent_attention').threadId,'child-thread')
  assert.notEqual(response.events.find(event=>event.type==='agent_attention').threadId,fixture.params.item.id)
  runner.finish(0)
  client.close()
 }
})

test('verified native thread reads recover topology from parent metadata or historical modern activity',async()=>{
 for(const source of ['child-metadata','parent-history']) {
  const client=new CodexClient()
  client.process={stdin:{write(){}},kill(){}}
  client.receive({id:0,method:'item/commandExecution/requestApproval',params:{threadId:'child'}})
  const thread=source==='child-metadata'?{id:'child',parentThreadId:'parent'}:{id:'parent',turns:[{items:[{type:'subAgentActivity',id:'ephemeral',kind:'started',agentThreadId:'child',agentPath:'/root/helper'}]}]}
  const pending=client.send('thread/read',{threadId:thread.id,includeTurns:true})
  client.receive({id:1,result:{thread}})
  await pending
  assert.equal(client.attentionForThread('parent').length,1)
  client.close()
 }
 const client=new CodexClient()
 client.process={stdin:{write(){}},kill(){}}
 const pending=client.send('thread/read',{threadId:'expected',includeTurns:true})
 client.receive({id:1,result:{thread:{id:'foreign-child',parentThreadId:'parent'}}})
 await pending
 assert.equal(client.parents.size,0)
 client.observeItem('observer',{type:'subAgentActivity',kind:'interacted',agentThreadId:'child'})
 assert.equal(client.parents.size,0)
 client.observeThread({id:'child',parentThreadId:'actual-parent'})
 client.observeItem('observer',{type:'subAgentActivity',kind:'started',agentThreadId:'child'})
 assert.equal(client.parents.get('child'),'actual-parent')
 client.close()
})

test('plan snapshots and deltas preserve item identity with authoritative final replacement and durable replay', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-plan-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const sessions = new CodexSessions(directory), client = new FakeClient()
  const runner = new CodexRunner({ sessionId: 'plan-session', threadId: 'thread-1' }, client, sessions)
  const response = new FakeResponse()
  runner.subscribe(response)
  const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/plan-items.json', import.meta.url), 'utf8'))
  for (const event of fixture) { client.emit('notification', event) }
  runner.finish(0)
  const plans = response.events.filter(event => event.event?.type === 'plan').map(envelope => ({ ...envelope.event, seq: envelope.seq }))
  assert.equal(plans.length, 6)
  assert.deepEqual(plans.map(event => [event.itemId, event.delta, event.completed]), [
    ['plan-a', false, false], ['plan-a', true, false], ['plan-b', false, false],
    ['plan-b', true, false], ['plan-a', false, true], ['plan-b', false, true]
  ])
  const rendered = new Map()
  for (const event of plans) { rendered.set(event.itemId, event.delta ? (rendered.get(event.itemId) || '') + event.text : event.text) }
  assert.equal(rendered.get('plan-a'), fixture[4].params.item.text)
  assert.equal(rendered.get('plan-b'), fixture[5].params.item.text)
  assert.ok(response.events.every(event => !event.codex && event.event?.type !== 'assistant'))
  assert.ok(plans.every((event, index) => index === 0 || event.seq === plans[index - 1].seq + 1))
  const replay = new FakeResponse(), finished = once(replay, 'finish')
  sessions.replay('plan-session', replay)
  await finished
  assert.deepEqual(replay.events.filter(event => event.event?.type === 'plan').map(envelope => ({ ...envelope.event, seq: envelope.seq })), plans)
})

test('Codex checklist state normalizes in-progress spelling and preserves its explanation', () => {
  const event = normalizedNotification('turn/plan/updated', { turnId: 'turn', explanation: 'The parser is already covered; focus on rendering.', plan: [
    { step: 'Inspect parser', status: 'completed' }, { step: 'Fix rendering', status: 'inProgress' }, { step: 'Run tests', status: 'pending' }
  ] })[0]
  assert.equal(event.message.content[0].input.explanation, 'The parser is already covered; focus on rendering.')
  assert.deepEqual(event.message.content[0].input.todos.map(item => item.status), ['completed', 'in_progress', 'pending'])
})

test('image generation keeps opaque results, saved artifact paths and quota failure metadata without guessing encoding', () => {
  const items = JSON.parse(fs.readFileSync(new URL('./fixtures/image-generation-items.json', import.meta.url), 'utf8'))
  for (const item of items) {
    const started = normalizedNotification('item/started', { item })[0].message.content[0]
    assert.equal(started.id, item.id)
    assert.equal(started.name, 'imageGeneration')
    const completed = normalizedNotification('item/completed', { item })[0].message.content[0]
    assert.equal(completed.tool_use_id, item.id)
    assert.deepEqual(JSON.parse(completed.content), item)
    assert.equal(completed.is_error, Boolean(item.failure))
  }
})

test('Stop interrupts late chat and review starts before acknowledgement and only once per turn', async (t) => {
  for (const review of [false, true]) {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-late-stop-'))
    t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
    const client = new FakeClient()
    const original = client.request.bind(client)
    const waiting = Promise.withResolvers()
    const acknowledgement = Promise.withResolvers()
    client.request = (method, params, timeout) => {
      if (method === (review ? 'review/start' : 'turn/start')) {
        client.calls.push({ method, params, timeout })
        waiting.resolve(timeout)
        return acknowledgement.promise
      }
      return original(method, params)
    }
    const runner = new CodexRunner({ sessionId: 'late-stop', ...(review ? { reviewTarget: { type: 'uncommittedChanges' } } : {}) }, client, new CodexSessions(directory))
    t.after(() => runner.finish(0))
    const started = runner.begin(directory, 'hello', [])
    assert.equal(await waiting.promise, null)
    runner.abort()
    client.emit('notification', { method: 'turn/started', params: { threadId: 'thread-1', turn: { id: 'late-turn' } } })
    assert.equal(client.calls.filter(call => call.method === 'turn/interrupt').length, 1)
    runner.abort()
    acknowledgement.resolve({ turn: { id: 'late-turn' }, reviewThreadId: 'thread-1' })
    await started
    assert.equal(client.calls.filter(call => call.method === 'turn/interrupt').length, 1)
    assert.deepEqual(client.calls.find(call => call.method === 'turn/interrupt').params, { threadId: 'thread-1', turnId: 'late-turn' })
    assert.equal(runner.hasExited, false)
    client.emit('notification', { method: 'turn/completed', params: { threadId: 'thread-1', turn: { id: 'late-turn', status: 'interrupted' } } })
    assert.equal(runner.hasExited, true)
  }
})

test('unacknowledged start RPCs settle on their observed turn completion and ignore unrelated events', async () => {
  for (const method of ['turn/start', 'review/start', 'thread/shellCommand']) {
    const client = new CodexClient()
    client.process = { stdin: { write() {} }, kill() {} }
    const pending = client.send(method, { threadId: 'task' }, client.process, null)
    client.receive({ method: 'turn/started', params: { threadId: 'task', turn: { id: 'owned-turn' } } })
    client.receive({ method: 'turn/completed', params: { threadId: 'other', turn: { id: 'owned-turn', status: 'completed' } } })
    assert.equal(client.pending.size, 1)
    client.receive({ method: 'turn/completed', params: { threadId: 'task', turn: { id: 'owned-turn', status: 'interrupted' } } })
    const result = await pending
    assert.equal(client.pending.size, 0)
    assert.deepEqual(result, method === 'thread/shellCommand' ? {} : { turn: { id: 'owned-turn', status: 'interrupted' }, ...(method === 'review/start' ? { reviewThreadId: 'task' } : {}) })
    client.receive({ id: 1, result: {} })
    const disconnected = client.send(method, { threadId: 'task' }, client.process, null)
    client.close()
    await assert.rejects(disconnected, /closed/)
  }
})

test('a changed API-key account cannot pass the preflight-to-start gap or steer a subscription turn', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-auth-transition-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  for (const duringStart of [true, false]) {
    const client = new FakeClient()
    const original = client.request.bind(client)
    let changed = false
    client.request = async (method, params) => {
      if (method === 'account/read' && changed) { return { account: { type: 'apiKey' } } }
      const result = await original(method, params)
      if (duringStart && method === 'thread/start') { changed = true }
      return result
    }
    const runner = new CodexRunner({ sessionId: 'transition' }, client, new CodexSessions(directory))
    t.after(() => runner.finish(1))
    if (duringStart) {
      await assert.rejects(runner.begin(directory, 'hello', []), /API key billing/)
      assert.equal(client.calls.some(call => call.method === 'turn/start'), false)
    } else {
      await runner.begin(directory, 'hello', [])
      changed = true
      await assert.rejects(runner.steer('more'), /API key billing/)
      assert.equal(client.calls.some(call => call.method === 'turn/steer'), false)
    }
  }
})

test('account notifications invalidate stale account reads and block approvals and inference without logging out', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-auth-event-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const client = new CodexClient()
  const wire = []
  client.process = { stdin: { write(line) { wire.push(JSON.parse(line)) } }, kill() {} }
  const runner = new CodexRunner({ sessionId: 'auth-event', threadId: 'task' }, client, new CodexSessions(directory))
  t.after(() => { runner.finish(1); client.close() })
  client.receive({ method: 'turn/started', params: { threadId: 'task', turn: { id: 'active' } } })
  client.receive({ id: 44, method: 'item/commandExecution/requestApproval', params: { threadId: 'task' } })
  const approval = client.requestsForThread('task')[0].requestKey
  const account = client.send('account/read', {})
  const accountId = wire.at(-1).id
  client.ready = Promise.resolve({})
  client.receive({ method: 'account/updated', params: { authMode: 'apikey' } })
  client.receive({ id: accountId, result: { account: { type: 'chatgpt' } } })
  await account
  await Promise.resolve()
  assert.equal(client.authMode, 'apikey')
  assert.equal(runner.cancelled, true)
  assert.equal(wire.filter(call => call.method === 'turn/interrupt').length, 1)
  assert.equal(client.respond(approval, { decision: 'accept' }, 'task'), false)
  for (const method of ['turn/start', 'review/start', 'turn/steer', 'thread/compact/start']) { await assert.rejects(client.send(method, { threadId: 'task' }), /authentication changed/) }
  assert.equal(wire.some(call => call.method === 'account/logout'), false)
  assert.notEqual(client.process, null)
})

test('closing a task releases only its unacknowledged start requests without waiting for a timer', async () => {
  for (const lifecycle of ['thread/closed', 'thread/archived', 'thread/deleted']) {
    const client = new CodexClient()
    client.process = { stdin: { write() {} }, kill() {} }
    const closed = client.send('turn/start', { threadId: 'closed' }, client.process, null)
    const other = client.send('review/start', { threadId: 'other' }, client.process, null)
    client.receive({ method: lifecycle, params: { threadId: 'closed' } })
    await assert.rejects(closed, /closed the task/)
    assert.equal(client.pending.size, 1)
    client.close()
    await assert.rejects(other, /connection closed/)
  }
})

test('steering cannot bypass newly exhausted subscription quota or a turn completed during revalidation', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-steer-quota-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  for (const completed of [false, true]) {
    const client = new FakeClient()
    const runner = new CodexRunner({ sessionId: 'steer-quota' }, client, new CodexSessions(directory))
    t.after(() => runner.finish(1))
    await runner.begin(directory, 'hello', [])
    const original = client.request.bind(client)
    client.request = async (method, params) => {
      if (method === 'account/rateLimits/read') {
        if (completed) { client.emit('notification', { method: 'turn/completed', params: { threadId: 'thread-1', turn: { id: 'turn-1', status: 'completed' } } }) }
        return { rateLimits: { primary: { usedPercent: completed ? 0 : 100 } } }
      }
      return original(method, params)
    }
    await assert.rejects(runner.steer('more'), completed ? /turn changed/ : /usage limit reached/)
    assert.equal(client.calls.some(call => call.method === 'turn/steer'), false)
  }
})

test('steering receipts share concurrent delivery and survive completed turns and daemon restarts without prompt storage', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-steer-receipt-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const sessions = new CodexSessions(directory)
  const acknowledgement = Promise.withResolvers()
  let calls = 0
  const perform = () => { calls += 1; return acknowledgement.promise }
  const id = '77777777-7777-4777-8777-777777777777'
  const first = sessions.steer('task', id, 'private prompt', perform)
  const second = sessions.steer('TASK', id.toUpperCase(), 'private prompt', perform)
  await Promise.resolve()
  assert.equal(calls, 1)
  await assert.rejects(sessions.steer('task', id, 'different prompt', perform), /another message/)
  acknowledgement.resolve({})
  await Promise.all([first, second])
  sessions.reset('task')
  await new CodexSessions(directory).steer('task', id, 'private prompt', perform)
  assert.equal(calls, 1)
  const receiptFile = fs.readdirSync(directory).find(file => file.includes('.steer-'))
  const contents = fs.readFileSync(path.join(directory, receiptFile), 'utf8')
  assert.equal(contents.includes('private prompt'), false)
  assert.deepEqual(Object.keys(JSON.parse(contents)).sort(), ['fingerprint', 'status'])
})

test('ambiguous steering receipts fail closed after interruption while other sessions remain independent', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-steer-ambiguous-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const sessions = new CodexSessions(directory)
  const id = '88888888-8888-4888-8888-888888888888'
  let calls = 0
  await assert.rejects(sessions.steer('task', id, 'hello', async () => { calls += 1; throw new Error('RPC acknowledgement lost') }), /lost/)
  await assert.rejects(new CodexSessions(directory).steer('task', id, 'hello', async () => { calls += 1 }), /already attempted/)
  assert.equal(calls, 1)
  await sessions.steer('other', id, 'hello', async () => { calls += 1 })
  assert.equal(calls, 2)
})

test('native helper turns remain tracked after owner completion and stale completion cannot clear newer work', () => {
  const client = new CodexClient()
  client.process = { stdin: { write() {} }, kill() {} }
  client.receive({ method: 'turn/started', params: { threadId: 'parent', turn: { id: 'parent-turn' } } })
  client.receive({ method: 'turn/started', params: { threadId: 'helper', turn: { id: 'helper-turn' } } })
  client.receive({ method: 'turn/completed', params: { threadId: 'parent', turn: { id: 'parent-turn' } } })
  assert.deepEqual([...client.activeTurns], [['helper', 'helper-turn']])
  client.receive({ method: 'turn/started', params: { threadId: 'helper', turn: { id: 'new-helper-turn' } } })
  client.receive({ method: 'turn/completed', params: { threadId: 'helper', turn: { id: 'helper-turn' } } })
  assert.equal(client.activeTurns.get('helper'), 'new-helper-turn')
  client.receive({ method: 'thread/closed', params: { threadId: 'helper' } })
  assert.equal(client.activeTurns.size, 0)
  client.receive({ method: 'turn/started', params: { threadId: 'helper', turn: { id: 'last-turn' } } })
  client.close()
  assert.equal(client.activeTurns.size, 0)
})

test('normal turn model metadata matches its explicit selected engine after a resumed host default differs', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-model-metadata-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  for (const review of [false, true]) {
    const client = new FakeClient()
    const runner = new CodexRunner({ sessionId: 'model-metadata', threadId: 'thread-1', model: 'selected-model', ...(review ? { reviewTarget: { type: 'uncommittedChanges' } } : {}) }, client, new CodexSessions(directory))
    const response = new FakeResponse()
    await runner.subscribe(response)
    await runner.begin(directory, 'hello', [])
    assert.equal(response.events.find(event => event.event?.subtype === 'init').event.model, review ? 'test-model' : 'selected-model')
    if (!review) {
      assert.equal(client.calls.find(call => call.method === 'turn/start').params.model, 'selected-model')
      assert.equal(client.calls.find(call => call.method === 'turn/start').params.collaborationMode.settings.model, 'selected-model')
    }
    runner.finish(0)
  }
})
