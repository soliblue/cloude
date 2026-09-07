import test, { after } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { once } from 'node:events'

const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-history-pages-'))
process.env.CLOUDE_DATA = directory
const { history, turns, importThread } = await import('../src/Handlers/CodexHandler.js')
const { codexClient } = await import('../src/Codex/CodexClient.js')
const { codexSessions } = await import('../src/Codex/CodexSessions.js')
const { default: HTTPServer } = await import('../src/Networking/HTTPServer.js')
const { daemonToken } = await import('../src/Routing/DaemonAuth.js')
const original = codexClient.request
const turn = { id: 'turn-one', status: 'completed', itemsView: 'full', items: [{ id: 'item-one', type: 'agentMessage', text: 'saved result' }] }
const request = (query = {}) => ({ query, headers: {} })
const body = response => JSON.parse(response.body)
after(() => { codexClient.request = original; fs.rmSync(directory, { recursive: true, force: true }) })

test('authenticated HTTP imports metadata and pages full turns without a full-history read or resume', async t => {
  const calls = []
  codexClient.request = async (method, params) => {
    calls.push({ method, params })
    if (method === 'thread/read') { return { thread: { id: params.threadId, cwd: directory, status: { type: 'idle' }, turns: params.includeTurns ? [turn] : [] } } }
    assert.equal(method, 'thread/turns/list')
    return { data: params.cursor ? [] : [turn], nextCursor: params.cursor ? null : 'opaque:+/=', backwardsCursor: params.cursor ? null : 'backwards:one' }
  }
  const server = new HTTPServer({ host: '127.0.0.1', port: 0 })
  server.start()
  await once(server.server, 'listening')
  t.after(() => { server.server.closeAllConnections(); server.server.close() })
  const url = `http://127.0.0.1:${server.server.address().port}`
  const headers = { Authorization: `Bearer ${daemonToken()}`, 'Content-Type': 'application/json' }
  assert.equal((await fetch(`${url}/sessions/alias/turns`)).status, 401)
  assert.equal(calls.length, 0)
  const detail = await fetch(`${url}/codex/threads/native?includeTurns=false`, { headers })
  assert.deepEqual((await detail.json()).thread.turns, [])
  assert.match(detail.headers.get('X-Daemon-Capabilities'), /codexHistoryPages/)
  const imported = await fetch(`${url}/sessions/alias/import`, { method: 'POST', headers, body: JSON.stringify({ threadId: 'native', includeTurns: false }) })
  assert.equal(imported.status, 200)
  assert.equal((await imported.json()).threadId, 'native')
  assert.equal(codexSessions.read('alias').threadId, 'native')
  assert.ok(calls.every(call => call.method === 'thread/read' && call.params.includeTurns === false))
  const metadata = await fetch(`${url}/sessions/alias/history?includeTurns=false`, { headers })
  assert.equal(metadata.status, 200)
  const etag = metadata.headers.get('ETag')
  assert.equal((await fetch(`${url}/sessions/alias/history?includeTurns=false`, { headers: { ...headers, 'If-None-Match': etag } })).status, 304)
  const page = await (await fetch(`${url}/sessions/alias/turns?limit=1&sortDirection=asc`, { headers })).json()
  assert.deepEqual(page, { threadId: 'native', data: [turn], nextCursor: 'opaque:+/=', backwardsCursor: 'backwards:one' })
  assert.deepEqual(calls.at(-1), { method: 'thread/turns/list', params: { threadId: 'native', limit: 1, sortDirection: 'asc', itemsView: 'full' } })
  const next = await (await fetch(`${url}/sessions/alias/turns?cursor=${encodeURIComponent(page.nextCursor)}`, { headers })).json()
  assert.deepEqual(next, { threadId: 'native', data: [], nextCursor: null, backwardsCursor: null })
  assert.equal(calls.at(-1).params.cursor, 'opaque:+/=')
  assert.equal(calls.at(-1).params.limit, 25)
  assert.equal(calls.at(-1).params.sortDirection, 'desc')
  const full = await (await fetch(`${url}/sessions/alias/history`, { headers })).json()
  assert.deepEqual(full.thread.turns, [turn])
  assert.equal(calls.at(-1).params.includeTurns, true)
})

test('history page filters reject malformed values before provider calls', async () => {
  codexClient.request = async () => assert.fail('invalid query reached provider')
  for (const query of [{ limit: '0' }, { limit: '51' }, { limit: '01' }, { limit: '1.0' }, { limit: '-1' }, { cursor: '' }, { cursor: ' ' }, { cursor: 'x\n' }, { cursor: 'x'.repeat(4097) }, { sortDirection: 'newest' }, { itemsView: 'summary' }, { extra: 'true' }]) {
    assert.equal((await turns(request(query), { id: 'native' })).status, 400)
  }
  for (const query of [{ includeTurns: 'yes' }, { includeTurns: '' }, { cursor: 'unexpected' }]) {
    assert.equal((await history(request(query), { id: 'native' })).status, 400)
  }
  assert.equal((await turns(request(), { id: '\u0000' })).status, 400)
  assert.equal((await importThread({ json: () => ({ threadId: 'native', includeTurns: 'false' }) }, { id: 'invalid-import' })).status, 400)
})

test('metadata-only imports retain full-history defaults and reject another task identity', async () => {
  const calls = []
  codexClient.request = async (method, params) => { calls.push({ method, params }); return { thread: { id: params.threadId, cwd: directory, turns: params.includeTurns ? [turn] : [] } } }
  const imported = await importThread({ json: () => ({ threadId: 'default-native' }) }, { id: 'full-alias' })
  assert.deepEqual(body(imported).thread.turns, [turn])
  assert.equal(calls.at(-1).params.includeTurns, true)
  codexClient.request = async () => ({ thread: { id: 'different', cwd: directory } })
  assert.equal((await history(request({ includeTurns: 'false' }), { id: 'native' })).status, 502)
  assert.equal((await importThread({ json: () => ({ threadId: 'native', includeTurns: false }) }, { id: 'wrong-identity' })).status, 502)
  assert.equal(codexSessions.read('wrong-identity'), null)
})

test('page replies must contain complete unique turns and valid bounded cursors', async () => {
  for (const result of [null, {}, { data: [{ ...turn, itemsView: 'summary' }] }, { data: [{ ...turn, itemsView: 'notLoaded' }] }, { data: [{ ...turn, items: null }] }, { data: [{ ...turn, status: 'unknown' }] }, { data: [turn, turn] }, { data: [turn], nextCursor: {} }, { data: [turn], backwardsCursor: '\u0000' }, { data: [turn, { ...turn, id: 'second' }] }]) {
    codexClient.request = async () => result
    assert.equal((await turns(request({ limit: '1' }), { id: 'native' })).status, 502)
  }
  codexClient.request = async () => { throw Error('private upstream token should not be returned') }
  const failed = await turns(request(), { id: 'native' })
  assert.equal(failed.status, 502)
  assert.doesNotMatch(failed.body.toString(), /private upstream/)
  codexClient.request = async () => ({ data: [{ id: 'legacy-turn', status: 'interrupted', items: [] }] })
  assert.equal((await turns(request(), { id: 'native' })).status, 200)
})

test('mapping changes during a metadata or page read reject the stale result', async () => {
  for (const action of [history, turns]) {
    codexSessions.write('moving-alias', { threadId: 'first', provider: 'codex' })
    let complete
    codexClient.request = () => new Promise(resolve => { complete = resolve })
    const pending = action(request(), { id: 'moving-alias' })
    codexSessions.write('moving-alias', { threadId: 'second', provider: 'codex' })
    complete({ thread: { id: 'first' }, data: [turn] })
    assert.equal((await pending).status, 409)
    assert.equal(codexSessions.read('moving-alias').threadId, 'second')
  }
})
