import test from 'node:test'
import assert from 'node:assert/strict'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { plugins, plugin, apps, readApps, mcp } from '../src/Handlers/CodexPluginHandler.js'
import { codexClient } from '../src/Codex/CodexClient.js'
import HTTPRequest from '../src/Networking/HTTPRequest.js'

function request(method = 'GET', query = {}, body = {}) { return new HTTPRequest(method, '/', query, {}, Buffer.from(JSON.stringify(body))) }
function mock(t, result = {}) {
  const original = codexClient.request
  const calls = []
  codexClient.request = async (method, params) => { calls.push({ method, params }); return result }
  t.after(() => { codexClient.request = original })
  return calls
}

test('plugin discovery reads catalogs with exact schema parameters and no implicit installation', async (t) => {
  const result = { marketplaces: [{ name: 'official', plugins: [] }], marketplaceLoadErrors: [] }
  const calls = mock(t, result)
  assert.deepEqual(JSON.parse((await plugins(request('GET', { path: '~/project', forceRefetch: 'true' }))).body), result)
  assert.equal((await plugins(request('GET', { path: '/project', installed: 'true' }))).status, 200)
  assert.equal((await plugin(request('GET', { pluginName: 'review', remoteMarketplaceName: 'official' }))).status, 200)
  assert.deepEqual(calls, [
    { method: 'plugin/list', params: { cwds: [join(homedir(), 'project')], forceRefetch: true } },
    { method: 'plugin/installed', params: { cwds: ['/project'] } },
    { method: 'plugin/read', params: { pluginName: 'review', remoteMarketplaceName: 'official' } }
  ])
})

test('explicit plugin install and uninstall preserve identity and native auth requirements', async (t) => {
  const result = { authPolicy: 'onUse', appsNeedingAuth: [{ id: 'app-one', name: 'App' }] }
  const calls = mock(t, result)
  assert.deepEqual(JSON.parse((await plugin(request('POST', {}, { pluginName: 'review', marketplacePath: '/local/marketplace', installAttemptId: 'attempt-one' }))).body), result)
  assert.equal((await plugin(request('DELETE', {}, { pluginId: 'review@official' }))).status, 200)
  assert.deepEqual(calls, [
    { method: 'plugin/install', params: { pluginName: 'review', marketplacePath: '/local/marketplace', installAttemptId: 'attempt-one' } },
    { method: 'plugin/uninstall', params: { pluginId: 'review@official' } }
  ])
})

test('apps and MCP preserve opaque pagination and route only to discovery methods', async (t) => {
  const result = { data: [{ id: 'app-one' }], nextCursor: 'next:opaque+/=' }
  const calls = mock(t, result)
  assert.deepEqual(JSON.parse((await apps(request('GET', { cursor: 'opaque+/=', limit: '100', threadId: 'thread', forceRefetch: 'true' }))).body), result)
  await apps(request('GET', { installed: 'true', threadId: 'thread', forceRefresh: 'false' }))
  await readApps(request('POST', {}, { appIds: ['app-one', 'app-one', 'app-two'], includeTools: true, threadId: 'thread' }))
  assert.deepEqual(JSON.parse((await mcp(request('GET', { cursor: 'mcp-next', limit: '10', threadId: 'thread', detail: 'toolsAndAuthOnly' }))).body), result)
  assert.deepEqual(calls, [
    { method: 'app/list', params: { limit: 100, forceRefetch: true, cursor: 'opaque+/=', threadId: 'thread' } },
    { method: 'app/installed', params: { forceRefresh: false, threadId: 'thread' } },
    { method: 'app/read', params: { appIds: ['app-one', 'app-two'], includeTools: true, threadId: 'thread' } },
    { method: 'mcpServerStatus/list', params: { limit: 10, detail: 'toolsAndAuthOnly', cursor: 'mcp-next', threadId: 'thread' } }
  ])
})

test('invalid plugin identities and unsupported fields never reach native RPC', async (t) => {
  const calls = mock(t)
  for (const value of [{ pluginName: 'x' }, { pluginName: '', remoteMarketplaceName: 'official' }, { pluginName: 'x', marketplacePath: 'relative' }, { pluginName: 'x', marketplacePath: '/local', remoteMarketplaceName: 'official' }, { pluginName: 'x', remoteMarketplaceName: 'official', apiKey: 'secret' }, { pluginName: 'x', remoteMarketplaceName: 'official', installAttemptId: 42 }]) {
    assert.equal((await plugin(request('POST', {}, value))).status, 400)
  }
  for (const query of [{ path: 'relative' }, { installed: 'yes' }, { forceRefetch: '1' }, { installed: 'true', forceRefetch: 'true' }, { cursor: 'not-supported' }]) {
    assert.equal((await plugins(request('GET', query))).status, 400)
  }
  assert.equal((await plugin(request('DELETE', {}, { pluginId: '../bad\0id' }))).status, 400)
  assert.deepEqual(calls, [])
})

test('app batch and pagination bounds reject malformed types and MCP mutation options', async (t) => {
  const calls = mock(t)
  for (const query of [{ limit: '0' }, { limit: '101' }, { limit: '-1' }, { limit: '1.5' }, { cursor: '' }, { threadId: '' }, { installed: 'true', cursor: 'unsupported' }, { installed: 'false', forceRefresh: 'true' }]) {
    assert.equal((await apps(request('GET', query))).status, 400)
  }
  for (const value of [{ appIds: [] }, { appIds: Array(101).fill('app') }, { appIds: [3] }, { appIds: ['app'], includeTools: 'true' }, { appIds: ['app'], threadId: null }, { appIds: ['app'], accessToken: 'secret' }]) {
    assert.equal((await readApps(request('POST', {}, value))).status, 400)
  }
  for (const query of [{ detail: 'full' }, { oauth: 'true' }, { limit: '10000' }, { threadId: 'line\nbreak' }]) {
    assert.equal((await mcp(request('GET', query))).status, 400)
  }
  assert.deepEqual(calls, [])
})

test('native errors identify operation and retain actionable message without credential material', async (t) => {
  const original = codexClient.request
  t.after(() => { codexClient.request = original })
  codexClient.request = async () => { throw new Error('Marketplace unavailable; sign in again. apiKey=private-value Bearer bearer-value https://example.invalid/path?token=url-value sk-api-value') }
  const response = await plugins(request())
  assert.equal(response.status, 502)
  const message = JSON.parse(response.body).error
  assert.match(message, /Codex plugin\/list failed: Marketplace unavailable; sign in again/)
  assert.doesNotMatch(message, /private-value|bearer-value|url-value|sk-api-value/)
})


test('upstream HTML errors retain the meaningful status without exposing challenge markup', async (t) => {
  const original = codexClient.request
  t.after(() => { codexClient.request = original })
  codexClient.request = async () => { throw new Error('failed to list apps: Request failed with status 403 Forbidden: <html><script>opaque-challenge</script></html>') }
  const response = await apps(request())
  assert.equal(response.status, 502)
  assert.match(JSON.parse(response.body).error, /403 Forbidden/)
  assert.doesNotMatch(JSON.parse(response.body).error, /html|script|opaque-challenge/)
})


test('thread-scoped discovery restores only an unloaded saved thread and retries the same read once', async (t) => {
  const original = codexClient.request
  t.after(() => { codexClient.request = original })
  for (const [handler, input, method] of [
    [apps, request('GET', { installed: 'true', threadId: 'saved-thread' }), 'app/installed'],
    [apps, request('GET', { threadId: 'saved-thread', cursor: 'page-two' }), 'app/list'],
    [readApps, request('POST', {}, { appIds: ['app-one'], threadId: 'saved-thread' }), 'app/read'],
    [mcp, request('GET', { threadId: 'saved-thread', cursor: 'page-two' }), 'mcpServerStatus/list']
  ]) {
    const calls = []
    codexClient.request = async (called, params) => {
      calls.push({ method: called, params })
      if (calls.length === 1) throw new Error('thread not found: saved-thread')
      if (called === 'thread/read') return { thread: { id: 'saved-thread', status: { type: 'notLoaded' } } }
      return { data: [], nextCursor: 'preserved' }
    }
    const response = await handler(input)
    assert.equal(response.status, 200)
    assert.deepEqual(calls.map((call) => call.method), [method, 'thread/read', 'thread/resume', method])
    assert.deepEqual(calls[0].params, calls[3].params)
    assert.deepEqual(calls[2].params, { threadId: 'saved-thread' })
    assert.equal(JSON.parse(response.body).nextCursor, 'preserved')
  }
})

test('unknown saved threads, unrelated errors and repeated missing-thread errors never loop or lose scope', async (t) => {
  const original = codexClient.request
  t.after(() => { codexClient.request = original })
  for (const variant of ['unknown', 'unrelated', 'different-id', 'repeated']) {
    const calls = []
    codexClient.request = async (method, params) => {
      calls.push({ method, params })
      if (method === 'thread/read' && variant !== 'unknown') return { thread: { id: 'saved-thread', status: { type: 'notLoaded' } } }
      if (method === 'thread/resume') return {}
      throw new Error(variant === 'unrelated' ? '403 Forbidden' : variant === 'different-id' ? 'thread not found: other-thread' : 'thread not found: saved-thread')
    }
    assert.equal((await apps(request('GET', { installed: 'true', threadId: 'saved-thread' }))).status, 502)
    assert.equal(calls.length, variant === 'unknown' ? 2 : variant === 'repeated' ? 4 : 1)
    assert.ok(calls.every((call) => call.params.threadId === 'saved-thread'))
  }
})
