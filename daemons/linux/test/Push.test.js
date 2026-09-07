import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import PushDelivery from '../src/Notifications/PushDelivery.js'

test('push retries survive restart with stable event identity and remove only acknowledged events', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cloude-push-test-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  fs.writeFileSync(path.join(directory, 'tunnel.json'), '{}')
  const options = { directory, identity: () => ({ installationId: 'host', secret: 'test-secret' }), transport: async () => ({ ok: false, status: 503 }) }
  const delivery = new PushDelivery(options)
  delivery.flushing = true
  assert.equal(delivery.enqueue('completed:task', 'POST', '/notifications', { sessionId: 'task', title: 'Done', body: 'Ready', kind: 'completed' }), true)
  const saved = JSON.parse(fs.readFileSync(delivery.file, 'utf8'))[0][1].id
  const sent = []
  const restored = new PushDelivery({ ...options, transport: async (url, request) => { sent.push({ url, request }); return { ok: true, status: 200 } } })
  await restored.flush()
  assert.equal(restored.queue.size, 0)
  assert.equal(JSON.parse(sent[0].request.body).eventId, saved)
  assert.equal(sent[0].request.headers['X-Mac-Secret'], 'test-secret')
  assert.equal(sent[0].url, 'https://remotecc.soli.blue/macs/host/notifications')
  assert.deepEqual(JSON.parse(fs.readFileSync(delivery.file, 'utf8')), [])
})

test('private endpoints do not enqueue undeliverable pushes and resolved requests are cancelled', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cloude-push-test-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const delivery = new PushDelivery({ directory })
  assert.equal(delivery.enqueue('request', 'POST', '/notifications', { sessionId: 'task', title: 'Waiting', body: 'Review', kind: 'attention' }), false)
  fs.writeFileSync(path.join(directory, 'tunnel.json'), '{}')
  delivery.flushing = true
  delivery.enqueue('request', 'POST', '/notifications', { sessionId: 'task', title: 'Waiting', body: 'Review', kind: 'attention' })
  delivery.cancel('request')
  assert.equal(delivery.queue.size, 0)
})

test('device registration is acknowledged before notifications and retries retain an updated token', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cloude-push-test-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  fs.writeFileSync(path.join(directory, 'tunnel.json'), '{}')
  const sent = []
  const delivery = new PushDelivery({ directory, identity: () => ({ installationId: 'host', secret: 'test' }), transport: async (url) => { sent.push(url); return { ok: true, status: 200 } } })
  delivery.flushing = true
  delivery.enqueue('notification', 'POST', '/notifications', { sessionId: 'task', title: 'Done', body: 'Ready', kind: 'completed' })
  delivery.enqueue('device', 'PUT', '/push-devices/device', { deviceId: 'device', token: 'a'.repeat(64), environment: 'production', bundleId: 'soli.Cloude' })
  delivery.flushing = false
  await delivery.flush()
  assert.ok(sent[0].endsWith('/push-devices/device'))
  assert.ok(sent[1].endsWith('/notifications'))
})

test('malformed, truncated and invalid-shaped push queues are privately quarantined without startup failure', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cloude-push-corrupt-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  const entry = ['completed:task', { id: 'd02831f9-224f-4bd4-883a-a79df6fe2c92', method: 'POST', route: '/notifications', createdAt: Date.now(), body: { sessionId: 'task', title: 'Done', body: 'Ready', kind: 'completed' } }]
  const malformed = ['{', '[', 'not-json', 'null', '{}', '"string"', JSON.stringify([null]), JSON.stringify([['bad']]), JSON.stringify([[1, entry[1]]]), JSON.stringify([entry, entry]), JSON.stringify([entry, ['other', entry[1]]]), ...[
    { id: 4 }, { createdAt: 'yesterday' }, { createdAt: -1 }, { method: 'DELETE' },
    { route: '/../../other-host/notifications' }, { body: [] }, { body: { title: 'Missing session' } },
    { method: 'PUT', route: '/push-devices/device', body: { deviceId: 'device', token: ['a'.repeat(64)], environment: 'production', bundleId: 'soli.Cloude' } },
    { method: 'PUT', route: '/push-devices/device', body: { deviceId: 'other', token: 'a'.repeat(64), environment: 'production', bundleId: 'soli.Cloude' } }
  ].map((override) => JSON.stringify([[entry[0], { ...entry[1], ...override }]]))]
  for (const [index, raw] of malformed.entries()) {
    const fixture = path.join(directory, String(index))
    fs.mkdirSync(fixture)
    fs.writeFileSync(path.join(fixture, 'push-queue.json'), raw)
    const delivery = new PushDelivery({ directory: fixture })
    assert.equal(delivery.queue.size, 0)
    assert.equal(fs.existsSync(delivery.file), false)
    const quarantined = fs.readdirSync(fixture).filter((name) => name.startsWith('push-queue.json.corrupt-'))
    assert.equal(quarantined.length, 1)
    assert.equal(fs.readFileSync(path.join(fixture, quarantined[0]), 'utf8'), raw)
    assert.equal(fs.statSync(path.join(fixture, quarantined[0])).mode & 0o777, 0o600)
    assert.equal(new PushDelivery({ directory: fixture }).queue.size, 0)
  }
})

test('quarantine failure preserves corrupt bytes and refuses a false durable acknowledgement', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cloude-push-quarantine-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  fs.writeFileSync(path.join(directory, 'push-queue.json'), '{truncated')
  fs.writeFileSync(path.join(directory, 'tunnel.json'), '{}')
  const rename = fs.renameSync
  t.after(() => { fs.renameSync = rename })
  fs.renameSync = () => { throw new Error('read-only fixture') }
  const delivery = new PushDelivery({ directory })
  assert.equal(delivery.queue.size, 0)
  assert.equal(delivery.enqueue('device:phone', 'PUT', '/push-devices/phone', { deviceId: 'phone', token: 'a'.repeat(64), environment: 'production', bundleId: 'soli.Cloude' }), false)
  assert.equal(fs.readFileSync(delivery.file, 'utf8'), '{truncated')
  fs.renameSync = rename
  assert.equal(delivery.persist(), true)
  assert.equal(new PushDelivery({ directory }).queue.size, 1)
})

test('an in-progress delivery lease remains queued for retry with its original event id', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cloude-push-lease-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  fs.writeFileSync(path.join(directory, 'tunnel.json'), '{}')
  const sent = []
  const delivery = new PushDelivery({ directory, identity: () => ({ installationId: 'host', secret: 'fixture' }), transport: async (_, request) => { sent.push(JSON.parse(request.body).eventId); return { ok: false, status: 409 } } })
  delivery.flushing = true
  delivery.enqueue('completed:task', 'POST', '/notifications', { sessionId: 'task', title: 'Done', body: 'Ready', kind: 'completed' })
  delivery.flushing = false
  await delivery.flush()
  await delivery.flush()
  assert.equal(delivery.queue.size, 1)
  assert.equal(sent.length, 2)
  assert.equal(sent[0], sent[1])
})

test('storage failures cannot break agent callbacks and canceled attention is persisted on recovery', async (t) => {
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'afto-push-storage-'))
  t.after(()=>fs.rmSync(directory,{recursive:true,force:true}))
  fs.writeFileSync(path.join(directory,'tunnel.json'),'{}')
  const delivery=new PushDelivery({directory,transport:async()=>{throw new Error('must not send canceled request')}})
  delivery.flushing=true
  delivery.enqueue('attention-child:fixture','POST','/notifications',{sessionId:'parent',title:'Waiting',body:'Open helper',kind:'attention'})
  const write=fs.writeFileSync
  fs.writeFileSync=()=>{throw new Error('full disk')}
  t.after(()=>{fs.writeFileSync=write})
  assert.doesNotThrow(()=>delivery.cancel('attention-child:fixture'))
  assert.equal(delivery.dirty,true)
  assert.equal(delivery.queue.size,0)
  await delivery.flush()
  assert.equal(JSON.parse(fs.readFileSync(delivery.file,'utf8')).length,1)
  fs.writeFileSync=write
  await delivery.flush()
  assert.equal(delivery.dirty,false)
  assert.deepEqual(JSON.parse(fs.readFileSync(delivery.file,'utf8')),[])
})

test('scheduled notification metadata requires complete UUID routing identities', () => {
  const delivery = Object.create(PushDelivery.prototype)
  const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  const entry = body => ['schedule', { id, createdAt: 0, method: 'POST', route: '/notifications', body: { sessionId: id, title: 'Scheduled agent', body: 'Open schedule', kind: 'attention', ...body } }]
  assert.equal(delivery.validEntry(entry({ scheduleId: id, runId: id })), true)
  assert.equal(delivery.validEntry(entry({ scheduleId: id })), false)
  assert.equal(delivery.validEntry(entry({ runId: id })), false)
  assert.equal(delivery.validEntry(entry({ scheduleId: id, runId: id, sessionId: 'not-a-uuid' })), false)
})
