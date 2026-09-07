import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { randomUUID } from 'node:crypto'
import { EventEmitter } from 'node:events'
import { nextOccurrence, validSchedule } from '../src/Codex/ScheduleTime.js'
import ScheduleStore from '../src/Codex/ScheduleStore.js'
import AgentSchedules from '../src/Codex/AgentSchedules.js'
import { schedules } from '../src/Handlers/ScheduleHandler.js'

const calendar = (timeZone, time, daysOfWeek = [1, 2, 3, 4, 5, 6, 7]) => ({ kind: 'calendar', timeZone, time, daysOfWeek })
const isoNext = (schedule, after) => new Date(nextOccurrence(schedule, Date.parse(after))).toISOString()
const request = (method, body = {}, query = {}) => ({ method, body: Buffer.from(JSON.stringify(body)), query })
const decode = response => JSON.parse(response.body)
const payload = (directory, extra = {}) => ({ requestId: randomUUID(), name: 'Daily code check', originSessionId: randomUUID(), task: { provider: 'codex', path: directory, prompt: 'Inspect and summarize the project.', permissionMode: 'default' }, schedule: { kind: 'interval', minutes: 15 }, enabled: false, ...extra })

function fixture(clock = Date.parse('2026-09-07T10:00:00Z')) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-schedules-'))
  const owner = Object.assign(new EventEmitter(), { owned: true, close() { this.owned = false } })
  const runtime = { clock, calls: [], runners: new Map(), start(options) {
    assert.ok(fs.readdirSync(directory).some(name => name.startsWith('claim-')))
    assert.ok(fs.readFileSync(path.join(directory, 'schedules.json'), 'utf8').includes(options.sessionId))
    this.calls.push(options)
    const runner = { hasExited: false, threadId: `native-${options.sessionId}`, requests: new Map(), childRequests: new Map(), finish(code = 0) { this.exitCode = code; this.hasExited = true; runtime.runners.delete(options.sessionId); options.onFinish(this) } }
    this.runners.set(options.sessionId, runner)
    return runner
  } }
  const store = new ScheduleStore(directory, owner, () => runtime.clock)
  const manager = new AgentSchedules(store, owner, runtime, { now: () => runtime.clock, notifications: { enqueue(...args) { runtime.notifications ||= []; runtime.notifications.push(args) } } })
  manager.activate()
  return { directory, owner, runtime, store, manager, close() { manager.close(); fs.rmSync(directory, { recursive: true, force: true }) } }
}

test('calendar schedules honor weekdays, timezone offsets, DST gaps, repeated hours and date boundaries', () => {
  assert.equal(isoNext(calendar('Europe/Berlin', '09:00', [1, 2, 3, 4, 5]), '2026-09-04T08:00:00Z'), '2026-09-07T07:00:00.000Z')
  assert.equal(isoNext(calendar('Asia/Kolkata', '09:00'), '2026-09-07T00:00:00Z'), '2026-09-07T03:30:00.000Z')
  assert.equal(isoNext(calendar('Europe/Berlin', '02:30'), '2026-03-28T03:00:00Z'), '2026-03-30T00:30:00.000Z')
  assert.equal(isoNext(calendar('Europe/Berlin', '02:30', [7]), '2026-03-28T03:00:00Z'), '2026-04-05T00:30:00.000Z')
  assert.equal(isoNext(calendar('Europe/Berlin', '02:30'), '2026-10-24T03:00:00Z'), '2026-10-25T00:30:00.000Z')
  assert.equal(isoNext(calendar('Europe/Berlin', '02:30'), '2026-10-25T00:45:00Z'), '2026-10-26T01:30:00.000Z')
  assert.equal(isoNext(calendar('Pacific/Auckland', '00:05'), '2026-12-31T10:00:00Z'), '2026-12-31T11:05:00.000Z')
  assert.equal(nextOccurrence({ kind: 'interval', minutes: 15 }, 1900000, 1000000), 2800000)
  for (const invalid of [calendar('Invalid/Zone', '09:00'), calendar('UTC', '24:00'), calendar('UTC', '09:00', [1, 1]), { kind: 'interval', minutes: 0 }, { kind: 'interval', minutes: 15, command: 'evil' }]) { assert.equal(validSchedule(invalid), false) }
})

test('creation defaults disabled; revision updates and deletion are explicit, strict and idempotent', async () => {
  const f = fixture()
  try {
    const body = payload(f.directory); delete body.enabled
    const created = await schedules(request('POST', body), {}, f.manager)
    assert.equal(created.status, 201)
    const job = decode(created)
    assert.equal(job.enabled, false)
    assert.equal(job.nextRunAt, null)
    assert.equal(job.revision, 1)
    assert.equal(decode(await schedules(request('POST', body), {}, f.manager)).id, job.id)
    assert.equal(f.runtime.calls.length, 0)
    const updated = await schedules(request('POST', { revision: 1, enabled: true }), { id: job.id, action: 'update' }, f.manager)
    assert.equal(decode(updated).revision, 2)
    assert.equal(decode(updated).nextRunAt, f.runtime.clock + 900000)
    assert.equal((await schedules(request('POST', { revision: 1, enabled: false }), { id: job.id, action: 'update' }, f.manager)).status, 409)
    assert.equal((await schedules(request('DELETE', { revision: 2 }), { id: job.id }, f.manager)).status, 200)
    assert.equal(f.store.list().length, 0)
    assert.equal((await schedules(request('POST', body), {}, f.manager)).status, 409)
  } finally { f.close() }
})

test('manual runs claim before spawning, use fresh task IDs, deduplicate retries, and never overlap', async () => {
  const f = fixture()
  try {
    const job = f.store.create(payload(f.directory)), requestId = randomUUID()
    const first = f.manager.runNow(job.id, requestId)
    const second = f.manager.runNow(job.id, requestId)
    assert.equal(first.runId, second.runId)
    assert.equal(f.runtime.calls.length, 1)
    assert.notEqual(first.sessionId, job.originSessionId)
    assert.equal(f.runtime.calls[0].threadId, undefined)
    assert.equal(f.runtime.calls[0].notify, false)
    assert.equal(f.runtime.calls[0].permissionMode, 'default')
    assert.throws(() => f.manager.runNow(job.id, randomUUID()), error => error.status === 409)
    assert.throws(() => f.store.remove(job.id, job.revision), error => error.status === 409)
    f.runtime.runners.get(first.sessionId).requests.set('approval', {})
    f.manager.tick()
    assert.equal(f.store.snapshot(f.store.get(job.id)).activeRun.status, 'waiting')
    f.runtime.runners.get(first.sessionId).finish(0)
    assert.equal(f.store.snapshot(f.store.get(job.id)).lastRun.status, 'completed')
    assert.equal(f.manager.runNow(job.id, requestId).runId, first.runId)
    const third = f.manager.runNow(job.id, randomUUID())
    assert.notEqual(third.sessionId, first.sessionId)
    f.runtime.runners.get(third.sessionId).finish(1)
    assert.equal(f.store.snapshot(f.store.get(job.id)).lastRun.status, 'failed')
  } finally { f.close() }
})

test('due ticks skip missed or overlapping occurrences and advance without catch-up model calls', () => {
  const f = fixture()
  try {
    const job = f.store.create(payload(f.directory, { enabled: true }))
    f.runtime.clock += 900000
    f.manager.tick()
    assert.equal(f.runtime.calls.length, 1)
    f.runtime.clock += 900000
    f.manager.tick()
    assert.equal(f.runtime.calls.length, 1)
    assert.equal(f.store.snapshot(f.store.get(job.id)).lastRun.status, 'skipped')
    f.runtime.runners.values().next().value.finish()
    f.runtime.clock += 7200000
    f.manager.tick()
    assert.equal(f.runtime.calls.length, 1)
    assert.match(f.store.snapshot(f.store.get(job.id)).lastRun.error, /missed/)
    assert.ok(f.store.get(job.id).nextRunAt > f.runtime.clock)
    f.manager.tick()
    assert.equal(f.runtime.calls.length, 1)
  } finally { f.close() }
})

test('crash recovery preserves claims, marks interrupted runs and skips startup occurrences', () => {
  const f = fixture()
  try {
    const job = f.store.create(payload(f.directory, { enabled: true }))
    const run = f.manager.runNow(job.id, randomUUID())
    f.runtime.clock += 900000
    const recovered = new ScheduleStore(f.directory, f.owner, () => f.runtime.clock)
    recovered.recover()
    assert.equal(recovered.state.runs.find(value => value.runId === run.runId).status, 'interrupted')
    assert.equal(recovered.snapshot(recovered.get(job.id)).lastRun.status, 'skipped')
    assert.ok(recovered.get(job.id).nextRunAt > f.runtime.clock)
    assert.equal(f.runtime.calls.length, 1)
    const recoveredManager = new AgentSchedules(recovered, f.owner, f.runtime, { now: () => f.runtime.clock, notifications: { enqueue() {} } })
    recoveredManager.activate()
    recoveredManager.tick()
    assert.equal(f.runtime.calls.length, 1)
  } finally { f.close() }
})

test('lost ownership and failed durable claims prevent inference, with readable availability errors', async () => {
  const f = fixture()
  try {
    const job = f.store.create(payload(f.directory, { enabled: true }))
    f.owner.owned = false; f.owner.emit('lost')
    f.runtime.clock += 900000
    f.manager.tick()
    assert.equal(f.runtime.calls.length, 0)
    assert.equal(decode(await schedules(request('GET'), {}, f.manager)).available, false)
    assert.equal((await schedules(request('POST', { requestId: randomUUID() }), { id: job.id, action: 'run' }, f.manager)).status, 503)
    f.owner.owned = true; f.manager.ready = true
    f.store.writeFile = () => { throw new Error('disk unavailable') }
    assert.equal((await schedules(request('POST', { requestId: randomUUID() }), { id: job.id, action: 'run' }, f.manager)).status, 503)
    assert.equal(f.runtime.calls.length, 0)
  } finally { f.close() }
})

test('schedule API rejects other providers, full access, malformed cadence and unsafe mutations before starting', async () => {
  const f = fixture()
  try {
    for (const changed of [ { task: { ...payload(f.directory).task, provider: 'claude' } }, { task: { ...payload(f.directory).task, permissionMode: 'bypassPermissions' } }, { schedule: calendar('UTC', 'bad') }, { enabled: 'yes' }, { task: { ...payload(f.directory).task, shellCommand: 'echo no' } } ]) {
      assert.equal((await schedules(request('POST', payload(f.directory, changed)), {}, f.manager)).status, 400)
    }
    assert.equal(f.store.list().length, 0)
    assert.equal(f.runtime.calls.length, 0)
  } finally { f.close() }
})

test('owner requires exact readiness, releases on lost child, and never treats spawn as a lock', async () => {
  const { default: ScheduleOwner } = await import('../src/Codex/ScheduleOwner.js')
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-schedule-lock-'))
  const child = Object.assign(new EventEmitter(), { stdout: new EventEmitter(), stdin: Object.assign(new EventEmitter(), { destroyed: false, destroy() { this.destroyed = true }, end() { this.destroyed = true } }) })
  const calls = []
  const owner = new ScheduleOwner(directory, (...args) => { calls.push(args); return child })
  try {
    owner.start()
    assert.equal(owner.owned, false)
    assert.equal(calls[0][0], '/usr/bin/flock')
    child.stdout.emit('data', Buffer.from('rea'))
    assert.equal(owner.owned, false)
    child.stdout.emit('data', Buffer.from('dy\n'))
    assert.equal(owner.owned, true)
    child.emit('exit', 75)
    assert.equal(owner.owned, false)
    assert.equal(child.stdin.destroyed, true)
    assert.match(owner.error, /flock/)
  } finally { owner.close(); fs.rmSync(directory, { recursive: true, force: true }) }
})

test('a claim written before a failed registry save is recovered without launching the run', () => {
  const f = fixture()
  try {
    const job = f.store.create(payload(f.directory)), requestId = randomUUID()
    const save = f.store.save.bind(f.store)
    f.store.save = () => { throw new Error('power loss after claim') }
    assert.throws(() => f.manager.runNow(job.id, requestId))
    assert.equal(f.runtime.calls.length, 0)
    f.store.save = save
    f.store.recover()
    assert.equal(f.store.state.runs.length, 1)
    assert.equal(f.store.state.runs[0].status, 'interrupted')
    assert.equal(f.manager.runNow(job.id, requestId).runId, f.store.state.runs[0].runId)
    assert.equal(f.runtime.calls.length, 0)
  } finally { f.close() }
})

test('corrupt schedule files are preserved and pause dispatch instead of silently resetting jobs', () => {
  const f = fixture()
  try {
    fs.writeFileSync(f.store.file, '{truncated')
    const store = new ScheduleStore(f.directory, f.owner, () => f.runtime.clock)
    assert.match(store.error, /preserved/)
    assert.throws(() => store.create(payload(f.directory)), error => error.status === 503)
    assert.equal(fs.readFileSync(f.store.file, 'utf8'), '{truncated')
    assert.equal(f.runtime.calls.length, 0)
  } finally { f.close() }
})

test('run pagination retains newest history and manual claim dedup survives metadata retention', async () => {
  const f = fixture()
  try {
    const job = f.store.create(payload(f.directory)), requestId = randomUUID()
    const first = f.manager.runNow(job.id, requestId)
    f.runtime.runners.get(first.sessionId).finish()
    for (let i = 0; i < 105; i++) {
      f.runtime.clock += 1
      const run = f.manager.runNow(job.id, randomUUID())
      f.runtime.runners.get(run.sessionId).finish()
    }
    assert.equal(f.store.state.runs.length, 100)
    const before = f.runtime.calls.length
    assert.equal(f.manager.runNow(job.id, requestId).runId, first.runId)
    assert.equal(f.manager.runNow(job.id, requestId).status, 'completed')
    assert.equal(f.runtime.calls.length, before)
    const page = decode(await schedules(request('GET', {}, { limit: '25' }), { id: job.id, action: 'runs' }, f.manager))
    assert.equal(page.runs.length, 25)
    assert.ok(page.nextCursor)
    const next = decode(await schedules(request('GET', {}, { limit: '25', cursor: page.nextCursor }), { id: job.id, action: 'runs' }, f.manager))
    assert.equal(next.runs.length, 25)
    assert.ok(!next.runs.some(run => page.runs.some(other => other.runId === run.runId)))
  } finally { f.close() }
})

test('saving unchanged timing preserves interval anchors and calendar weekday ordering is structural', () => {
  const f = fixture()
  try {
    const job = f.store.create(payload(f.directory, { enabled: true, schedule: { kind: 'interval', minutes: 60 } }))
    const due = job.nextRunAt
    f.runtime.clock += 3540000
    const edited = f.store.update(job.id, { revision: job.revision, name: 'Renamed', task: { ...job.task, prompt: 'A new prompt' }, schedule: { minutes: 60, kind: 'interval' } })
    assert.equal(edited.nextRunAt, due)
    const changed = f.store.update(job.id, { revision: edited.revision, schedule: { kind: 'interval', minutes: 30 } })
    assert.equal(changed.nextRunAt, f.runtime.clock + 1800000)
    const weekly = f.store.create(payload(f.directory, { enabled: true, schedule: calendar('Europe/Berlin', '09:00', [1, 3, 5]) }))
    assert.equal(f.store.update(weekly.id, { revision: 1, schedule: calendar('Europe/Berlin', '09:00', [5, 1, 3]) }).nextRunAt, weekly.nextRunAt)
  } finally { f.close() }
})

test('pre-thread failures preserve actionable sanitized errors and push dedicated schedule navigation', () => {
  const f = fixture()
  try {
    const start = f.runtime.start.bind(f.runtime)
    f.runtime.start = options => { const runner = start(options); delete runner.threadId; return runner }
    const job = f.store.create(payload(f.directory)), run = f.manager.runNow(job.id, randomUUID())
    const runner = f.runtime.runners.get(run.sessionId)
    runner.lastError = 'Codex subscription usage limit reached. Bearer secret-token'
    runner.finish(1)
    const failed = f.store.snapshot(f.store.get(job.id)).lastRun
    assert.equal(failed.threadId, undefined)
    assert.match(failed.error, /usage limit reached/)
    assert.doesNotMatch(failed.error, /secret-token|Open the run/)
    const notification = f.runtime.notifications.at(-1)[3]
    assert.equal(notification.sessionId, job.originSessionId)
    assert.equal(notification.scheduleId, job.id)
    assert.equal(notification.runId, run.runId)
    assert.equal(notification.kind, 'failed')
    assert.doesNotMatch(notification.body, /secret-token/)
    assert.deepEqual(f.runtime.calls[0].notificationContext, { sessionId: job.originSessionId, scheduleId: job.id, runId: run.runId })
  } finally { f.close() }
})

test('scheduled approval push navigation is distinct from its unchanged execution session', async () => {
  const { default: CodexRunner } = await import('../src/Codex/CodexRunner.js')
  const { pushDelivery } = await import('../src/Notifications/PushDelivery.js')
  const original = pushDelivery.enqueue, deliveries = []
  pushDelivery.enqueue = (...args) => deliveries.push(args)
  try {
    const sessionId = randomUUID(), context = { sessionId: randomUUID(), scheduleId: randomUUID(), runId: randomUUID() }
    CodexRunner.prototype.notifyAttention.call({ notificationContext: context }, 'attention:execution', { sessionId, title: 'Approval needed', body: 'Open task', kind: 'attention' })
    assert.equal(deliveries[0][0], 'attention:execution')
    assert.deepEqual(deliveries[0][3], { ...context, title: 'A scheduled agent needs attention', body: 'Open the scheduled run to review its request and continue.', kind: 'attention' })
    assert.notEqual(deliveries[0][3].sessionId, sessionId)
  } finally { pushDelivery.enqueue = original }
})

test('delete/create cycles do not consume active capacity and deleted jobs retain no prompt or path', () => {
  const f = fixture()
  try {
    const original = payload(f.directory), first = f.store.create(original)
    f.store.remove(first.id, first.revision)
    for (let index = 0; index < 105; index++) {
      const job = f.store.create(payload(f.directory))
      f.store.remove(job.id, job.revision)
    }
    assert.equal(f.store.list().length, 0)
    assert.ok(f.store.state.schedules.every(job => Object.keys(job).sort().join(',') === 'deleted,fingerprint,id,requestId'))
    assert.throws(() => f.store.create(original), error => error.status === 409)
    const restored = new ScheduleStore(f.directory, f.owner, () => f.runtime.clock)
    assert.equal(restored.error, null)
    assert.equal(restored.list().length, 0)
    assert.ok(restored.create(payload(f.directory)).id)
  } finally { f.close() }
})

test('all public schedule run surfaces expose only task-facing fields and preserve private idempotency records', async () => {
  const f = fixture()
  try {
    const job = f.store.create(payload(f.directory)), requestId = randomUUID()
    const run = decode(await schedules(request('POST', { requestId }), { id: job.id, action: 'run' }, f.manager))
    assert.ok(run.runId && run.sessionId && run.threadId)
    const publicResponses = [
      run,
      decode(await schedules(request('POST', { requestId }), { id: job.id, action: 'run' }, f.manager)),
      decode(await schedules(request('GET'), { id: job.id }, f.manager)),
      decode(await schedules(request('GET'), {}, f.manager)),
      decode(await schedules(request('GET'), { id: job.id, action: 'runs' }, f.manager)),
      decode(await schedules(request('POST', { revision: 1, name: 'Renamed' }), { id: job.id, action: 'update' }, f.manager))
    ]
    for (const response of publicResponses) { assert.doesNotMatch(JSON.stringify(response), /claimFile|occurrenceKey|requestId|fingerprint|lastAutomaticClaim|anchorAt/) }
    const stored = f.store.state.runs.find(value => value.runId === run.runId)
    assert.ok(stored.claimFile && stored.occurrenceKey && stored.requestId)
    assert.equal(f.manager.runNow(job.id, requestId).runId, run.runId)
  } finally { f.close() }
})

test('a metadata write failure after native start pauses scheduling without falsely completing or overlapping the live run', () => {
  const f = fixture()
  try {
    const job = f.store.create(payload(f.directory)), update = f.store.updateRun.bind(f.store)
    f.store.updateRun = (id, fields) => { if (fields.status === 'running') { throw new Error('temporary registry failure') }; return update(id, fields) }
    const run = f.manager.runNow(job.id, randomUUID())
    assert.equal(run.status, 'starting')
    assert.equal(f.manager.available, false)
    assert.equal(f.store.busy(job.id), true)
    assert.equal(f.runtime.calls.length, 1)
    assert.equal(f.manager.active.has(run.runId), true)
    assert.throws(() => f.manager.runNow(job.id, randomUUID()), error => error.status === 503)
    f.runtime.runners.get(run.sessionId).finish()
    assert.equal(f.store.snapshot(f.store.get(job.id)).lastRun.status, 'completed')
    assert.equal(f.runtime.calls.length, 1)
  } finally { f.close() }
})

test('old automatic claim cleanup failures do not suppress a durably claimed new occurrence', () => {
  const f = fixture(), remove = fs.rmSync
  try {
    const job = f.store.create(payload(f.directory, { enabled: true }))
    f.runtime.clock += 900000; f.manager.tick()
    f.runtime.runners.values().next().value.finish()
    fs.rmSync = (file, options) => { if (String(file).includes('claim-')) { throw new Error('cleanup unavailable') }; return remove(file, options) }
    f.runtime.clock += 900000; f.manager.tick()
    assert.equal(f.runtime.calls.length, 2)
    assert.equal(f.manager.available, true)
    assert.equal(f.store.snapshot(f.store.get(job.id)).activeRun.status, 'running')
  } finally { fs.rmSync = remove; f.close() }
})
