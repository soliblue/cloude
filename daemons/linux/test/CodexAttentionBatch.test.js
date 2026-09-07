import test, { after } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { once } from 'node:events'

const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-attention-batch-'))
process.env.CLOUDE_DATA = directory
const { attention, requests } = await import('../src/Handlers/CodexHandler.js')
const { codexClient } = await import('../src/Codex/CodexClient.js')
const { codexSessions } = await import('../src/Codex/CodexSessions.js')
const { runnerManager } = await import('../src/RunnerManager.js')
const { default: HTTPServer } = await import('../src/Networking/HTTPServer.js')
const { daemonToken } = await import('../src/Routing/DaemonAuth.js')
const original = codexClient.request
const request = value => ({ json: () => value, body: Buffer.from(JSON.stringify(value)) })
const body = response => JSON.parse(response.body)
after(() => { codexClient.request = original; runnerManager.runners.clear(); codexClient.serverRequests.clear(); codexClient.parents.clear(); codexClient.owners.clear(); fs.rmSync(directory, { recursive: true, force: true }) })

test('attention batch matches per-session cards, isolates child approval, and never calls Codex', () => {
  codexClient.request = async () => assert.fail('attention performed RPC')
  codexSessions.write('PhoneParent', { threadId: 'parent-native', provider: 'codex' })
  codexSessions.write('PhoneChild', { threadId: 'child-native', provider: 'codex' })
  codexClient.parents.set('child-native', 'parent-native')
  codexClient.owners.set('parent-native', 'phoneparent')
  const direct = { id: 9, requestKey: 'generation:9', method: 'item/commandExecution/requestApproval', params: { threadId: 'parent-native', command: 'fixture' } }
  const child = { id: 'wire-string', requestKey: 'generation:10', method: 'item/permissions/requestApproval', params: { threadId: 'child-native', permissions: { network: { enabled: true } } } }
  codexClient.serverRequests.set(direct.requestKey, direct)
  codexClient.serverRequests.set(child.requestKey, child)
  runnerManager.runners.set('phoneparent', { threadId: 'parent-native', requests: new Map([[direct.requestKey, direct]]) })
  const snapshot = body(attention(request({ sessionIds: ['PHONEPARENT', 'PhoneChild', 'unknown', 'parent-native'] })))
  assert.deepEqual(snapshot.sessions.map(value => value.sessionId), ['PHONEPARENT', 'PhoneChild', 'unknown', 'parent-native'])
  assert.deepEqual(snapshot.sessions.map(value => value.threadId), ['parent-native', 'child-native', 'unknown', 'parent-native'])
  for (const entry of snapshot.sessions) {
    const { sessionId, threadId, ...cards } = entry
    assert.deepEqual(cards, body(requests({}, { id: sessionId })))
  }
  assert.deepEqual(snapshot.sessions[0].requests.map(value => value.requestId), ['generation:9'])
  assert.deepEqual(snapshot.sessions[0].agentAttention, [{ threadId: 'child-native', requestId: 'generation:10' }])
  assert.deepEqual(snapshot.sessions[1].requests[0].params.permissions, child.params.permissions)
  assert.deepEqual(snapshot.sessions[2].requests, [])
  codexClient.serverRequests.delete(child.requestKey)
  assert.deepEqual(body(attention(request({ sessionIds: ['PHONEPARENT'] }))).sessions[0].agentAttention, [])
  codexClient.serverRequests.clear()
  runnerManager.runners.clear()
})

test('attention validates bounds and preserves empty arrays, Unicode lengths and exact spelling', () => {
  for (const value of [{}, { sessionIds: null }, { sessionIds: 'one' }, { sessionIds: [null] }, { sessionIds: [''] }, { sessionIds: [' '] }, { sessionIds: ['a\n'] }, { sessionIds: ['x'.repeat(513)] }, { sessionIds: ['😀'.repeat(257)] }, { sessionIds: ['same', 'same'] }, { sessionIds: ['a'], extra: true }, { sessionIds: Array.from({ length: 101 }, (_, i) => String(i)) }]) {
    assert.equal(attention(request(value)).status, 400)
  }
  assert.deepEqual(body(attention(request({ sessionIds: [] }))), { sessions: [] })
  assert.equal(attention(request({ sessionIds: ['Case', 'case', '😀'.repeat(256)] })).status, 200)
  assert.equal(attention(request({ sessionIds: Array.from({ length: 100 }, (_, i) => String(i)) })).status, 200)
  assert.equal(attention({ body: Buffer.alloc(512 * 1024 + 1), json: () => assert.fail('oversized body decoded') }).status, 413)
})

test('HTTP attention requires authentication and performs no model or history RPC', async t => {
  codexClient.request = async () => assert.fail('HTTP attention performed RPC')
  const server = new HTTPServer({ host: '127.0.0.1', port: 0 })
  server.start()
  await once(server.server, 'listening')
  t.after(() => { server.server.closeAllConnections(); server.server.close() })
  const url = `http://127.0.0.1:${server.server.address().port}/codex/attention`
  assert.equal((await fetch(url, { method: 'POST', body: '{"sessionIds":[]}' })).status, 401)
  const headers = { Authorization: `Bearer ${daemonToken()}`, 'Content-Type': 'application/json' }
  const response = await fetch(url, { method: 'POST', headers, body: '{"sessionIds":["missing"]}' })
  assert.equal(response.status, 200)
  assert.match(response.headers.get('X-Daemon-Capabilities'), /codexAttentionBatch/)
  assert.deepEqual(await response.json(), { sessions: [{ sessionId: 'missing', threadId: 'missing', requests: [], agentAttention: [] }] })
  assert.equal((await fetch(url, { method: 'POST', headers, body: 'null' })).status, 400)
  assert.equal((await fetch(url, { method: 'POST', headers, body: '[' })).status, 400)
  assert.equal((await fetch(url, { method: 'GET', headers })).status, 404)
})
