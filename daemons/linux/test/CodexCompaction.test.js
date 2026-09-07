import test from 'node:test'
import assert from 'node:assert/strict'
import { EventEmitter } from 'node:events'
import CodexCompaction, { codexCompaction } from '../src/Codex/CodexCompaction.js'
import { start as startChat } from '../src/Handlers/ChatHandler.js'

function fixture(overrides = {}) {
  const client = new EventEmitter()
  const calls = []
  const defaults = {
    'thread/read': { thread: { id: 'thread', cwd: '/actual/project', modelProvider: 'openai', status: { type: 'idle' } } },
    'account/read': { account: { type: 'chatgpt' } },
    'config/read': { config: {} },
    'account/rateLimits/read': { rateLimits: { primary: { usedPercent: 10 }, secondary: { usedPercent: 20 } } },
    'thread/resume': { thread: { id: 'thread', status: { type: 'idle' } }, modelProvider: 'openai' },
    'thread/compact/start': {}
  }
  client.request = async (method, params) => {
    calls.push({ method, params })
    return typeof overrides[method] === 'function' ? overrides[method](params, client) : overrides[method] || defaults[method]
  }
  const sessions = { read: (id) => id === 'missing' ? undefined : { provider: 'codex', threadId: 'thread', path: '/stale/project' } }
  const runners = { runners: new Map() }
  const compaction = new CodexCompaction(client, sessions, runners)
  return { client, calls, compaction, runners }
}
function notify(client, method, params = {}) { client.emit('notification', { method, params: { threadId: 'thread', ...params } }) }

test('compaction verifies subscription and actual thread cwd then tracks completion and fresh usage', async () => {
  const { client, calls, compaction } = fixture()
  assert.deepEqual(compaction.state('session'), { status: 'idle', threadId: 'thread' })
  assert.equal((await compaction.start('session')).statusCode, 202)
  assert.deepEqual(calls.map((call) => call.method), ['thread/read', 'account/read', 'config/read', 'account/rateLimits/read', 'thread/resume', 'thread/compact/start'])
  assert.deepEqual(calls.find((call) => call.method === 'config/read').params, { cwd: '/actual/project', includeLayers: false })
  assert.deepEqual(calls.at(-2).params, { threadId: 'thread', cwd: '/actual/project', modelProvider: 'openai' })
  assert.deepEqual(calls.at(-1).params, { threadId: 'thread' })
  notify(client, 'turn/started', { turn: { id: 'compact-turn' } })
  notify(client, 'item/started', { turnId: 'compact-turn', item: { id: 'item', type: 'contextCompaction' } })
  notify(client, 'thread/tokenUsage/updated', { tokenUsage: { last: { totalTokens: 1200 }, modelContextWindow: 200000 } })
  notify(client, 'item/completed', { turnId: 'compact-turn', item: { id: 'item', type: 'contextCompaction' } })
  assert.equal(compaction.state('session').status, 'pending')
  notify(client, 'turn/completed', { turn: { id: 'unrelated', status: 'failed' } })
  assert.equal(compaction.state('session').status, 'pending')
  notify(client, 'turn/completed', { turn: { id: 'compact-turn', status: 'completed' } })
  assert.equal(compaction.state('session').status, 'completed')
  assert.equal(compaction.state('session').contextTokens, 1200)
  assert.equal(compaction.state('session').contextWindow, 200000)
  assert.ok(compaction.state('session').completedAt)
  notify(client, 'thread/tokenUsage/updated', { tokenUsage: { last: { totalTokens: 2400 }, modelContextWindow: 200000 } })
  assert.equal(compaction.state('session').contextTokens, 2400)
  assert.ok(compaction.state('session').usageAt)
})

test('API keys, quota exhaustion, custom providers and unexpected resumed provider block inference', async () => {
  for (const overrides of [
    { 'account/read': { account: { type: 'apiKey' } } },
    { 'account/rateLimits/read': { rateLimits: { secondary: { usedPercent: 100 } } } },
    { 'config/read': { config: { model_providers: { openai: { base_url: 'https://paid.invalid' } } } } },
    { 'thread/read': { thread: { modelProvider: 'paid', cwd: '/actual/project', status: { type: 'idle' } } } },
    { 'thread/resume': { modelProvider: 'paid' } }
  ]) {
    const { compaction, calls } = fixture(overrides)
    assert.equal((await compaction.start('session')).statusCode, 403)
    assert.equal(calls.filter((call) => call.method === 'thread/compact/start').length, 0)
    assert.equal(compaction.state('session').status, 'failed')
  }
})

test('active sessions and thread aliases are rejected and a pending compaction prevents new chat', async () => {
  const local = fixture()
  local.runners.runners.set('other-session', { threadId: 'thread', hasExited: false })
  assert.equal((await local.compaction.start('session')).statusCode, 409)
  assert.equal(local.calls.length, 0)
  const remote = fixture({ 'thread/read': { thread: { modelProvider: 'openai', cwd: '/actual/project', status: { type: 'active' } } } })
  assert.equal((await remote.compaction.start('session')).statusCode, 409)
  assert.deepEqual(remote.calls.map((call) => call.method), ['thread/read'])
  codexCompaction.states.set('test-compaction-guard', { state: { status: 'pending' } })
  const response = startChat({ body: Buffer.from(JSON.stringify({ provider: 'codex', threadId: 'test-compaction-guard', path: '/project', prompt: 'next turn' })) }, { id: 'test-session' })
  codexCompaction.states.delete('test-compaction-guard')
  assert.equal(response.status, 409)
})

test('duplicate starts during preflight and compaction share one native operation', async () => {
  let release
  const { compaction, calls } = fixture({ 'thread/read': () => new Promise((resolve) => { release = resolve }) })
  const first = compaction.start('session')
  assert.equal((await compaction.start('alias')).statusCode, 202)
  release({ thread: { cwd: '/actual/project', modelProvider: 'openai', status: { type: 'idle' } } })
  assert.equal((await first).statusCode, 202)
  assert.equal((await compaction.start('alias')).statusCode, 202)
  assert.equal(calls.filter((call) => call.method === 'thread/compact/start').length, 1)
})

test('completion before native response is retained, unrelated notifications are ignored', async () => {
  const { compaction } = fixture({ 'thread/compact/start': (_, client) => {
    notify(client, 'thread/compacted', { threadId: 'other' })
    notify(client, 'thread/compacted')
    return {}
  } })
  const result = await compaction.start('session')
  assert.equal(result.statusCode, 200)
  assert.equal(result.state.status, 'completed')
  assert.equal(result.state.contextTokens, undefined)
})

test('native failure and disconnect clear pending state without exposing secrets or starting late inference', async () => {
  const failed = fixture({ 'thread/compact/start': () => Promise.reject(new Error('private token')) })
  assert.equal((await failed.compaction.start('session')).statusCode, 502)
  assert.equal(failed.compaction.state('session').status, 'failed')
  assert.doesNotMatch(failed.compaction.state('session').error, /private token/)
  let release
  const disconnected = fixture({ 'thread/read': () => new Promise((resolve) => { release = resolve }) })
  const started = disconnected.compaction.start('session')
  disconnected.client.emit('disconnected', new Error('private token'))
  release({ thread: { cwd: '/actual/project', modelProvider: 'openai', status: { type: 'idle' } } })
  assert.equal((await started).state.status, 'failed')
  assert.equal(disconnected.calls.filter((call) => call.method === 'thread/compact/start').length, 0)
  const reloaded = fixture()
  assert.equal(reloaded.compaction.state('session').status, 'idle')
  assert.equal((await reloaded.compaction.start('missing')).statusCode, 404)
})


test('matching compaction failure, interrupted turn and post-start disconnect release the operation', async () => {
  for (const outcome of ['failed', 'interrupted', 'disconnected']) {
    const { client, compaction } = fixture()
    await compaction.start('session')
    notify(client, 'turn/started', { turn: { id: 'compact-turn' } })
    if (outcome === 'disconnected') client.emit('disconnected', new Error('private token'))
    else notify(client, 'turn/completed', { turn: { id: 'compact-turn', status: outcome, error: { message: 'private token' } } })
    assert.equal(compaction.state('session').status, 'failed')
    assert.equal(compaction.busy('thread'), false)
    assert.doesNotMatch(compaction.state('session').error, /private token/)
  }
})
