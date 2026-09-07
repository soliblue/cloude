import test from 'node:test'
import assert from 'node:assert/strict'
import { EventEmitter } from 'node:events'
import CodexLogin from '../src/Codex/CodexLogin.js'

const device = (loginId) => ({ type: 'chatgptDeviceCode', loginId, userCode: 'ONE-TIME-CODE', verificationUrl: 'https://auth.openai.com/codex/device' })
function fixture(request) {
  const client = new EventEmitter()
  client.calls = []
  client.request = async (method, params) => { client.calls.push({ method, params }); return request(method, params) }
  return { client, login: new CodexLogin(client) }
}
function completed(client, loginId, success = true) { client.emit('notification', { method: 'account/login/completed', params: { loginId, success } }) }

test('duplicate sign-in starts share one native request and terminal notifications erase device code', async () => {
  let finish
  const { client, login } = fixture(() => new Promise((resolve) => { finish = resolve }))
  const first = login.start()
  const duplicate = login.start()
  assert.equal(first, duplicate)
  assert.deepEqual(login.snapshot(), { status: 'pending' })
  finish(device('first'))
  assert.deepEqual(await first, { status: 'pending', loginId: 'first', userCode: 'ONE-TIME-CODE', verificationUrl: device('first').verificationUrl })
  await login.start()
  assert.deepEqual(client.calls, [{ method: 'account/login/start', params: { type: 'chatgptDeviceCode' } }])
  completed(client, 'stale')
  completed(client, null)
  assert.equal(login.snapshot().status, 'pending')
  completed(client, 'first')
  assert.deepEqual(login.snapshot(), { status: 'completed', loginId: 'first' })
  completed(client, 'first', false)
  assert.equal(login.snapshot().status, 'completed')
})

test('completion before start response is matched by login ID and stale notifications cannot end the new attempt', async () => {
  let finish
  const { client, login } = fixture(() => new Promise((resolve) => { finish = resolve }))
  let pending = login.start()
  completed(client, 'stale')
  completed(client, 'first')
  finish(device('first'))
  assert.deepEqual(await pending, { status: 'completed', loginId: 'first' })
  pending = login.start()
  completed(client, 'first')
  finish(device('second'))
  assert.equal((await pending).status, 'pending')
  completed(client, 'first', false)
  assert.equal(login.snapshot().status, 'pending')
  completed(client, 'second', false)
  assert.equal(login.snapshot().status, 'failed')
  assert.equal(login.snapshot().userCode, undefined)
  assert.equal(login.snapshot().verificationUrl, undefined)
})

test('cancel while starting waits for ID, deduplicates cancellation and never logs out', async () => {
  let finish
  const { client, login } = fixture((method) => method === 'account/login/start' ? new Promise((resolve) => { finish = resolve }) : { status: 'canceled' })
  const pending = login.start()
  const cancellation = login.cancel()
  assert.equal(cancellation, login.cancel())
  assert.equal(login.start(), cancellation)
  finish(device('cancel-me'))
  await pending
  assert.deepEqual(await cancellation, { status: 'canceled', loginId: 'cancel-me' })
  completed(client, 'cancel-me')
  assert.equal(login.snapshot().status, 'canceled')
  await login.cancel()
  assert.deepEqual(client.calls, [{ method: 'account/login/start', params: { type: 'chatgptDeviceCode' } }, { method: 'account/login/cancel', params: { loginId: 'cancel-me' } }])
})

test('completion wins a cancellation race and cancellation failures remain retryable', async () => {
  let cancelFinish
  let cancelFails = true
  const { client, login } = fixture((method) => {
    if (method === 'account/login/start') return device('race')
    if (cancelFails) return Promise.reject(new Error('private authentication detail'))
    return new Promise((resolve) => { cancelFinish = resolve })
  })
  await login.start()
  assert.equal((await login.cancel()).status, 'pending')
  assert.match(login.snapshot().error, /Try again/)
  assert.doesNotMatch(JSON.stringify(login.snapshot()), /private authentication/)
  cancelFails = false
  const canceling = login.cancel()
  await Promise.resolve()
  completed(client, 'race')
  cancelFinish({ status: 'notFound' })
  assert.deepEqual(await canceling, { status: 'completed', loginId: 'race' })
})

test('disconnect invalidates active and starting codes without exposing native errors', async () => {
  let finish
  const { client, login } = fixture(() => new Promise((resolve) => { finish = resolve }))
  const pending = login.start()
  client.emit('disconnected', new Error('private token'))
  finish(device('disconnected'))
  assert.equal((await pending).status, 'failed')
  assert.equal(login.snapshot().userCode, undefined)
  assert.doesNotMatch(JSON.stringify(login.snapshot()), /private token/)
  completed(client, 'disconnected')
  assert.equal(login.snapshot().status, 'failed')
})

test('unexpected auth variants and untrusted verification URLs never expose credentials', async () => {
  for (const result of [{ type: 'apiKey', apiKey: 'secret' }, { type: 'chatgptAuthTokens', accessToken: 'secret' }, { ...device('bad'), verificationUrl: 'https://auth.openai.com.evil.invalid/codex/device' }, { ...device('bad'), verificationUrl: 'http://auth.openai.com/codex/device' }]) {
    const { client, login } = fixture(() => result)
    assert.equal((await login.start()).status, 'failed')
    assert.equal(login.snapshot().userCode, undefined)
    assert.doesNotMatch(JSON.stringify(login.snapshot()), /secret|evil/)
    assert.deepEqual(client.calls[0].params, { type: 'chatgptDeviceCode' })
  }
})

test('HTTP login input accepts only device code and account stays separate', async (t) => {
  const { login } = await import('../src/Handlers/CodexHandler.js')
  const { codexClient } = await import('../src/Codex/CodexClient.js')
  const { default: HTTPRequest } = await import('../src/Networking/HTTPRequest.js')
  const original = codexClient.request
  t.after(() => { codexClient.request = original })
  const calls = []
  codexClient.request = async (method, params) => { calls.push({ method, params }); return method === 'account/login/start' ? device('http') : { status: 'canceled' } }
  const request = (method, value) => new HTTPRequest(method, '/codex/login', {}, {}, Buffer.from(value === undefined ? '' : JSON.stringify(value)))
  assert.equal((await login(request('GET'))).status, 200)
  assert.equal(calls.length, 0)
  for (const value of [{ type: 'apiKey', apiKey: 'secret' }, { type: 'chatgptAuthTokens' }, { type: 'chatgpt' }, { type: 'chatgptDeviceCode', accessToken: 'secret' }]) {
    assert.equal((await login(request('POST', value))).status, 400)
  }
  assert.equal(calls.length, 0)
  assert.equal((await login(request('POST'))).status, 200)
  assert.equal((await login(request('POST', {}))).status, 200)
  assert.equal((await login(request('POST', { type: 'chatgptDeviceCode' }))).status, 200)
  assert.equal(calls.length, 1)
  assert.equal((await login(request('DELETE'))).status, 200)
  assert.deepEqual(calls.map((call) => call.method), ['account/login/start', 'account/login/cancel'])
})


test('cancel acknowledgment classifies its failure notification as canceled in either ordering', async () => {
  for (const notificationFirst of [true, false]) {
    let finish
    const { client, login } = fixture((method) => method === 'account/login/start' ? device('cancel-notify') : new Promise((resolve) => { finish = resolve }))
    await login.start()
    const canceling = login.cancel()
    await Promise.resolve()
    if (notificationFirst) completed(client, 'cancel-notify', false)
    assert.equal(login.snapshot().status, 'pending')
    finish({ status: 'canceled' })
    assert.deepEqual(await canceling, { status: 'canceled', loginId: 'cancel-notify' })
    completed(client, 'cancel-notify', false)
    assert.deepEqual(login.snapshot(), { status: 'canceled', loginId: 'cancel-notify' })
  }
})
