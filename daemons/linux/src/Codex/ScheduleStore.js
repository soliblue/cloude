import fs from 'node:fs'
import path from 'node:path'
import { createHash, randomUUID } from 'node:crypto'
import { validSchedule, nextOccurrence } from './ScheduleTime.js'

const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i
const active = new Set(['starting', 'running', 'waiting'])

export default class ScheduleStore {
  constructor(directory, owner, now = Date.now) {
    this.directory = directory
    this.owner = owner
    this.now = now
    this.file = path.join(directory, 'schedules.json')
    this.error = null
    this.state = { version: 1, schedules: [], runs: [] }
    this.load()
  }

  load() {
    try {
      if (fs.existsSync(this.file)) {
        const state = JSON.parse(fs.readFileSync(this.file, 'utf8'))
        if (state.version !== 1 || !Array.isArray(state.schedules) || !Array.isArray(state.runs) || new Set(state.schedules.map(job => job.id)).size !== state.schedules.length || new Set(state.runs.map(run => run.runId)).size !== state.runs.length || !state.schedules.every(job => job.deleted === true ? uuid.test(job.id) && uuid.test(job.requestId) && typeof job.fingerprint === 'string' && /^[a-f0-9]{64}$/.test(job.fingerprint) && Object.keys(job).every(key => ['id', 'requestId', 'fingerprint', 'deleted'].includes(key)) : uuid.test(job.id) && Number.isSafeInteger(job.revision) && job.revision > 0 && (job.lastAutomaticClaim === undefined || /^claim-[a-f0-9]{64}\.json$/.test(job.lastAutomaticClaim)) && typeof job.enabled === 'boolean' && (job.nextRunAt === null && !job.enabled || Number.isSafeInteger(job.nextRunAt) && job.nextRunAt >= 0) && Number.isSafeInteger(job.anchorAt) && job.anchorAt >= 0 && uuid.test(job.originSessionId) && validSchedule(job.schedule) && job.task?.provider === 'codex' && Object.keys(job.task).every(key => ['provider', 'path', 'prompt', 'model', 'effort', 'permissionMode'].includes(key)) && ['default', 'plan'].includes(job.task.permissionMode) && typeof job.task.prompt === 'string' && typeof job.task.path === 'string' && path.isAbsolute(job.task.path)) || !state.runs.every(run => uuid.test(run.runId) && uuid.test(run.sessionId) && uuid.test(run.scheduleId) && /^claim-[a-f0-9]{64}\.json$/.test(run.claimFile || '') && ['starting', 'running', 'waiting', 'completed', 'failed', 'interrupted', 'skipped'].includes(run.status))) { throw new Error('Invalid schedule state') }
        this.state = state
      }
    } catch { this.error = 'Schedule storage is unreadable. Existing files are preserved; scheduling is paused.' }
  }

  requireOwner() {
    if (!this.owner.owned || this.error) { throw Object.assign(new Error(this.error || this.owner.error || 'Scheduling is unavailable.'), { status: 503 }) }
  }

  writeFile(file, value, exclusive = false) {
    fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 })
    const descriptor = fs.openSync(file, exclusive ? 'wx' : 'w', 0o600)
    try { fs.writeFileSync(descriptor, JSON.stringify(value)); fs.fsyncSync(descriptor) } finally { fs.closeSync(descriptor) }
  }

  save(state) {
    this.requireOwner()
    const counts = new Map()
    state = { ...state, runs: state.runs.slice().sort((a, b) => a.createdAt - b.createdAt).reverse().filter(run => { const count = counts.get(run.scheduleId) || 0; counts.set(run.scheduleId, count + 1); return active.has(run.status) || count < 100 }).reverse() }
    this.writeFile(`${this.file}.tmp`, state)
    fs.renameSync(`${this.file}.tmp`, this.file)
    const directory = fs.openSync(this.directory, 'r')
    try { fs.fsyncSync(directory) } finally { fs.closeSync(directory) }
    this.state = state
  }

  runSnapshot(run) {
    return run ? Object.fromEntries(['runId', 'sessionId', 'scheduleId', 'originSessionId', 'name', 'provider', 'path', 'threadId', 'scheduledFor', 'createdAt', 'startedAt', 'finishedAt', 'status', 'error'].filter(key => run[key] !== undefined).map(key => [key, run[key]])) : null
  }

  snapshot(job) {
    const runs = this.state.runs.filter(run => run.scheduleId === job.id)
    const { fingerprint, requestId, anchorAt, deleted, lastAutomaticClaim, ...visible } = job
    return { ...visible, activeRun: this.runSnapshot(runs.find(run => active.has(run.status))), lastRun: this.runSnapshot(runs.at(-1)) }
  }
  list() { return this.state.schedules.filter(job => !job.deleted).map(job => this.snapshot(job)) }
  get(id) { return this.state.schedules.find(job => job.id === id && !job.deleted) }
  busy(id) { return this.state.runs.some(run => run.scheduleId === id && active.has(run.status)) }

  create(body) {
    this.requireOwner()
    const fingerprint = createHash('sha256').update(JSON.stringify(body)).digest('hex')
    const existing = this.state.schedules.find(job => job.requestId === body.requestId)
    if (existing) {
      if (existing.fingerprint !== fingerprint || existing.deleted) { throw Object.assign(new Error('This creation request ID has already been used.'), { status: 409 }) }
      return this.snapshot(existing)
    }
    if (this.state.schedules.filter(job => !job.deleted).length >= 100) { throw Object.assign(new Error('This endpoint has reached its 100-schedule limit.'), { status: 409 }) }
    const job = { ...body, id: randomUUID(), fingerprint, revision: 1, createdAt: this.now(), updatedAt: this.now(), anchorAt: this.now(), nextRunAt: body.enabled ? nextOccurrence(body.schedule, this.now(), this.now()) : null }
    this.save({ ...this.state, schedules: [...this.state.schedules, job] })
    return this.snapshot(job)
  }

  update(id, body) {
    this.requireOwner()
    const job = this.get(id)
    if (!job) { throw Object.assign(new Error('Schedule not found.'), { status: 404 }) }
    if (job.revision !== body.revision) { throw Object.assign(new Error('The schedule changed. Reload it before saving.'), { status: 409 }) }
    const next = { ...job, ...body, revision: job.revision + 1, updatedAt: this.now() }
    const sameTiming = next.schedule.kind === job.schedule.kind && (next.schedule.kind === 'interval' ? next.schedule.minutes === job.schedule.minutes : next.schedule.time === job.schedule.time && next.schedule.timeZone === job.schedule.timeZone && [...next.schedule.daysOfWeek].sort().join(',') === [...job.schedule.daysOfWeek].sort().join(','))
    if (!sameTiming || body.enabled !== undefined && body.enabled !== job.enabled) { next.anchorAt = this.now(); next.nextRunAt = next.enabled ? nextOccurrence(next.schedule, this.now(), next.anchorAt) : null }
    this.save({ ...this.state, schedules: this.state.schedules.map(value => value.id === id ? next : value) })
    return this.snapshot(next)
  }

  remove(id, revision) {
    if (this.busy(id)) { throw Object.assign(new Error('Stop the active scheduled run before deleting this schedule.'), { status: 409 }) }
    this.requireOwner()
    const job = this.get(id)
    if (!job) { throw Object.assign(new Error('Schedule not found.'), { status: 404 }) }
    if (job.revision !== revision) { throw Object.assign(new Error('The schedule changed. Reload it before deleting.'), { status: 409 }) }
    this.save({ ...this.state, schedules: this.state.schedules.map(value => value.id === id ? { id, requestId: job.requestId, fingerprint: job.fingerprint, deleted: true } : value) })
    return { ok: true }
  }

  claimFile(id, key) { return path.join(this.directory, `claim-${createHash('sha256').update(`${id}:${key}`).digest('hex')}.json`) }

  readClaim(file) {
    const claim = JSON.parse(fs.readFileSync(file, 'utf8'))
    if (!uuid.test(claim.runId) || !uuid.test(claim.sessionId) || !uuid.test(claim.scheduleId) || !['starting', 'running', 'waiting', 'completed', 'failed', 'interrupted', 'skipped'].includes(claim.status) || !/^claim-[a-f0-9]{64}\.json$/.test(claim.claimFile || '')) { throw new Error('Invalid schedule claim') }
    return claim
  }

  lookupClaim(id, key) {
    const file = this.claimFile(id, key)
    if (!fs.existsSync(file)) { return null }
    const claim = this.readClaim(file)
    return this.state.runs.find(run => run.runId === claim.runId) || claim
  }

  claim(job, key, scheduledFor, nextRunAt, status = 'starting', error) {
    this.requireOwner()
    const file = this.claimFile(job.id, key)
    const existing = this.lookupClaim(job.id, key)
    if (existing) {
      if (job.nextRunAt !== nextRunAt) { this.save({ ...this.state, schedules: this.state.schedules.map(value => value.id === job.id ? { ...value, nextRunAt } : value) }) }
      return { claimed: false, run: existing }
    }
    const run = { runId: randomUUID(), sessionId: randomUUID(), scheduleId: job.id, originSessionId: job.originSessionId, name: job.name, provider: 'codex', path: job.task.path, scheduledFor, createdAt: this.now(), status, claimFile: path.basename(file), occurrenceKey: key, ...(status === 'skipped' ? { finishedAt: this.now() } : {}), ...(error ? { error } : {}) }
    this.writeFile(file, run, true)
    this.save({ ...this.state, schedules: this.state.schedules.map(value => value.id === job.id ? { ...value, nextRunAt, ...(key.startsWith('scheduled:') ? { lastAutomaticClaim: run.claimFile } : {}) } : value), runs: [...this.state.runs, run] })
    if (key.startsWith('scheduled:') && job.lastAutomaticClaim && job.lastAutomaticClaim !== run.claimFile) {
      try { fs.rmSync(path.join(this.directory, job.lastAutomaticClaim), { force: true }) } catch {}
    }
    return { claimed: true, run }
  }

  updateRun(runId, fields) {
    this.requireOwner()
    const run = this.state.runs.find(run => run.runId === runId)
    if (run?.claimFile) {
      const file = path.join(this.directory, run.claimFile)
      this.writeFile(`${file}.tmp`, { ...run, ...fields })
      fs.renameSync(`${file}.tmp`, file)
    }
    this.save({ ...this.state, runs: this.state.runs.map(run => run.runId === runId ? { ...run, ...fields } : run) })
  }

  recover() {
    this.requireOwner()
    this.load()
    this.requireOwner()
    let state = { ...this.state, runs: this.state.runs.map(run => active.has(run.status) ? { ...run, status: 'interrupted', finishedAt: this.now(), error: 'The daemon restarted during this run. It was not retried.' } : run) }
    for (const name of fs.readdirSync(this.directory).filter(name => /^claim-[a-f0-9]{64}\.json$/.test(name))) {
      const claim = this.readClaim(path.join(this.directory, name))
      if (!state.runs.some(run => run.runId === claim.runId)) { state.runs.push(active.has(claim.status) ? { ...claim, status: 'interrupted', finishedAt: this.now(), error: 'The daemon restarted before this run started. It was not retried.' } : claim) }
    }
    this.save(state)
    for (const job of this.state.schedules.filter(job => job.enabled && !job.deleted && job.nextRunAt <= this.now())) { this.claim(job, `scheduled:${job.nextRunAt}`, job.nextRunAt, nextOccurrence(job.schedule, this.now(), job.anchorAt), 'skipped', 'Skipped while the endpoint was stopped. Missed runs are not replayed.') }
  }
}
