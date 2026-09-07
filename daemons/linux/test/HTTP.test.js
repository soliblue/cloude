import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { once } from 'node:events'

const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cloude-http-test-'))
process.env.CLOUDE_DATA = directory
const { default: HTTPServer } = await import('../src/Networking/HTTPServer.js')
const { daemonToken } = await import('../src/Routing/DaemonAuth.js')
const { codexClient } = await import('../src/Codex/CodexClient.js')

test('authenticated HTTP drives Codex chat, import, fork, history, models and durable replay', { timeout: 10000 }, async (t) => {
  const server = new HTTPServer({ host: '127.0.0.1', port: 0 })
  server.start()
  await once(server.server, 'listening')
  t.after(() => { server.server.closeAllConnections(); server.server.close(); fs.rmSync(directory, { recursive: true, force: true }) })
  const url = `http://127.0.0.1:${server.server.address().port}`
  const headers = { Authorization: `Bearer ${daemonToken()}`, 'Content-Type': 'application/json' }
  const original = codexClient.request
  t.after(() => { codexClient.request = original })
  const calls = []
  let completeFirstTurn
  codexClient.request = async (method, params) => {
    calls.push({ method, params })
    if (method === 'account/read') { return { account: { type: 'chatgpt' } } }
    if (method === 'config/read') { return { config: {} } }
    if (method === 'account/rateLimits/read') { return { rateLimits: { primary: { usedPercent: 0 } } } }
    if (method === 'skills/list') { return { data: [{ cwd: directory, skills: [{ name: 'review', description: 'Review a change', path: '/skills/review/SKILL.md', enabled: true }], errors: [] }] } }
    if (method === 'model/list') { return { data: [{ id: 'subscription-model', model: 'subscription-model', isDefault: true }] } }
    if (method === 'turn/start' || method === 'review/start') {
      const complete = () => {
        codexClient.emit('notification', { method: 'item/agentMessage/delta', params: { threadId: 'thread-http', delta: 'hello' } })
        codexClient.emit('notification', { method: 'turn/completed', params: { threadId: 'thread-http', turn: { id: 'turn-http', status: 'completed' } } })
      }
      if (completeFirstTurn === undefined) { completeFirstTurn = complete } else { setTimeout(complete, 10) }
      return { turn: { id: 'turn-http' }, ...(method === 'review/start' ? { reviewThreadId: 'thread-http' } : {}) }
    }
    return { thread: { id: method === 'thread/fork' ? 'fork-http' : 'thread-http', cwd: directory, turns: ['thread/read', 'thread/fork'].includes(method) ? [{ id: 'turn-http', status: 'completed', items: [] }] : [] }, modelProvider: 'openai', model: 'subscription-model' }
  }
  assert.equal((await fetch(`${url}/codex/models`)).status, 401)
  assert.equal((await fetch(`${url}/codex/login`, { method: 'POST' })).status, 401)
  assert.deepEqual(await (await fetch(`${url}/codex/login`, { headers })).json(), { status: 'idle' })
  assert.equal((await fetch(`${url}/codex/login`, { method: 'POST', headers, body: JSON.stringify({ type: 'apiKey', apiKey: 'not-a-real-key' }) })).status, 400)
  assert.equal(calls.length, 0)
  const pluginCatalog = await fetch(`${url}/codex/plugins?installed=true`, { headers })
  assert.equal(pluginCatalog.status, 200)
  assert.match(pluginCatalog.headers.get('X-Daemon-Capabilities'), /codexPlugins/)
  assert.equal((await fetch(`${url}/codex/plugin?pluginName=review&remoteMarketplaceName=official`, { headers })).status, 200)
  assert.equal((await fetch(`${url}/codex/plugin`, { method: 'POST', headers, body: JSON.stringify({ pluginName: 'review', remoteMarketplaceName: 'official' }) })).status, 200)
  assert.equal((await fetch(`${url}/codex/plugin`, { method: 'DELETE', headers, body: JSON.stringify({ pluginId: 'review@official' }) })).status, 200)
  assert.equal((await fetch(`${url}/codex/apps?installed=true`, { headers })).status, 200)
  assert.equal((await fetch(`${url}/codex/apps/read`, { method: 'POST', headers, body: JSON.stringify({ appIds: ['app-one'], includeTools: true }) })).status, 200)
  assert.equal((await fetch(`${url}/codex/mcp?detail=toolsAndAuthOnly`, { headers })).status, 200)
  assert.deepEqual(calls.map((call) => call.method), ['plugin/installed', 'plugin/read', 'plugin/install', 'plugin/uninstall', 'app/installed', 'app/read', 'mcpServerStatus/list'])
  assert.equal((await fetch(`${url}/codex/mcp`, { method: 'POST', headers, body: '{}' })).status, 404)

  assert.equal((await (await fetch(`${url}/codex/models`, { headers })).json()).data[0].id, 'subscription-model')
  const response = await fetch(`${url}/sessions/session-http/chat`, { method: 'POST', headers, body: JSON.stringify({ path: directory, prompt: 'hello', provider: 'codex' }) })
  assert.equal(response.status, 200)
  assert.equal((await fetch(`${url}/sessions/duplicate/chat`, { method: 'POST', headers, body: JSON.stringify({ path: directory, prompt: 'duplicate', provider: 'codex', threadId: 'thread-http' }) })).status, 409)
  completeFirstTurn()
  const events = (await response.text()).trim().split('\n').map((line) => JSON.parse(line))
  assert.equal(events.at(-1).type, 'exit')
  assert.ok(events.some((event) => event.event?.event?.delta?.text === 'hello'))
  const reviewed = await fetch(`${url}/sessions/review-http/chat`, { method: 'POST', headers, body: JSON.stringify({ path: directory, prompt: 'Review working changes', provider: 'codex', reviewTarget: { type: 'uncommittedChanges' } }) })
  assert.equal(reviewed.status, 200)
  const reviewEvents = (await reviewed.text()).trim().split('\n').map((line) => JSON.parse(line))
  assert.equal(reviewEvents.at(-1).type, 'exit')
  assert.deepEqual(calls.find((call) => call.method === 'review/start').params, { threadId: 'thread-http', delivery: 'inline', target: { type: 'uncommittedChanges' } })
  assert.equal(calls.find((call) => call.method === 'thread/start').params.modelProvider, 'openai')
  const replay = await (await fetch(`${url}/sessions/session-http/chat/resume?after_seq=2`, { headers })).text()
  assert.deepEqual(replay.trim().split('\n').slice(1).map((line) => JSON.parse(line)), events)
  const imported = await (await fetch(`${url}/sessions/import-http/import`, { method: 'POST', headers, body: JSON.stringify({ threadId: 'thread-http' }) })).json()
  assert.equal(imported.threadId, 'thread-http')
  assert.deepEqual(await (await fetch(`${url}/sessions/import-http/compact`, { headers })).json(), { status: 'idle', threadId: 'thread-http' })
  assert.equal((await fetch(`${url}/sessions/import-http/compact`, { method: 'POST', headers, body: JSON.stringify({ model: 'unsupported' }) })).status, 400)
  const forked = await (await fetch(`${url}/sessions/session-http/fork`, { method: 'POST', headers, body: JSON.stringify({ newSessionId: 'fork-session' }) })).json()
  assert.equal(forked.threadId, 'fork-http')
  assert.equal(calls.find(call => call.method === 'thread/fork').params.lastTurnId, 'turn-http')
  assert.deepEqual(forked.thread.turns, [{ id: 'turn-http', status: 'completed', items: [] }])
  assert.equal((await fetch(`${url}/sessions/import-http/name`, { method: 'POST', headers, body: JSON.stringify({ name: 'Renamed task' }) })).status, 200)
  assert.equal(calls.find((call) => call.method === 'thread/name/set').params.name, 'Renamed task')
  const history = await fetch(`${url}/sessions/import-http/history`, { headers })
  assert.equal(history.status, 200)
  assert.ok(history.headers.get('ETag'))
  assert.equal((await fetch(`${url}/sessions/import-http/history`, { headers: { ...headers, 'If-None-Match': history.headers.get('ETag') } })).status, 304)
  assert.equal((await fetch(`${url}/sessions/invalid/chat`, { method: 'POST', headers, body: JSON.stringify({ path: 5, prompt: 'hi', provider: 'codex' }) })).status, 400)
  assert.equal((await fetch(`${url}/sessions/session-http/fork`, { method: 'POST', headers, body: JSON.stringify({ newSessionId: 'fork-session' }) })).status, 409)
  await fetch(`${url}/codex/threads`, { headers })
  assert.equal(calls.findLast((call) => call.method === 'thread/list').params.useStateDbOnly, true)
  for (const search of ['', '   ']) {
    const result = await fetch(`${url}/codex/threads?search=${encodeURIComponent(search)}&archived=false`, { headers })
    assert.equal(result.status, 200)
    assert.equal(calls.findLast(call => call.method === 'thread/list').params.searchTerm, undefined)
  }
  const searched = await fetch(`${url}/codex/threads?search=%20needle%20`, { headers })
  assert.equal(searched.status, 200)
  assert.equal(calls.findLast(call => call.method === 'thread/list').params.searchTerm, 'needle')
  for (const query of ['search=%00', 'search=%0A', 'cursor=', 'cursor=%20', 'path=', 'sectionId=']) {
    const previous = calls.length
    assert.equal((await fetch(`${url}/codex/threads?${query}`, { headers })).status, 400)
    assert.equal(calls.length, previous)
  }
  await fetch(`${url}/codex/threads?refresh=true`, { headers })
  assert.equal(calls.findLast((call) => call.method === 'thread/list').params.useStateDbOnly, false)
  const manifest = await (await fetch(`${url}/sessions/import-http/manifest?provider=codex&path=${encodeURIComponent(directory)}`, { headers })).json()
  assert.equal(manifest.skills[0].path, '/skills/review/SKILL.md')
  assert.equal((await fetch(`${url}/sessions/import-http/goal`, { method: 'POST', headers, body: JSON.stringify({ objective: 'Finish tests', tokenBudget: 1000 }) })).status, 200)
  assert.equal(calls.find((call) => call.method === 'thread/goal/set').params.tokenBudget, 1000)
  assert.equal((await fetch(`${url}/sessions/import-http/goal`, { method: 'POST', headers, body: JSON.stringify({ objective: '', tokenBudget: -1 }) })).status, 400)
  assert.equal((await fetch(`${url}/sessions/invalid/import`, { method: 'POST', headers, body: '{' })).status, 400)
  for (const body of ['null', '[]', '"string"']) {
    assert.equal((await fetch(`${url}/sessions/invalid/import`, { method: 'POST', headers, body })).status, 400)
  }
  assert.equal((await fetch(`${url}/sessions/session-http/chat/respond`, { method: 'POST', headers, body: JSON.stringify({ requestId: 'expired', result: { decision: 'accept' } }) })).status, 409)
})
