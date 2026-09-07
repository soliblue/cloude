import { pushDelivery } from '../Notifications/PushDelivery.js'
import { scheduleFailure } from './ScheduleFailure.js'
import os from 'node:os'
import path from 'node:path'
import { runnerManager } from '../RunnerManager.js'
import ScheduleStore from './ScheduleStore.js'
import ScheduleOwner from './ScheduleOwner.js'
import { nextOccurrence } from './ScheduleTime.js'

export default class AgentSchedules {
  constructor(store, owner, runners, { now = Date.now, graceMs = 60000, notifications = pushDelivery } = {}) {
    this.store = store
    this.owner = owner
    this.runners = runners
    this.now = now
    this.graceMs = graceMs
    this.notifications = notifications
    this.active = new Map()
    this.timer = null
    this.error = null
    this.ready = false
    owner.on?.('ready', () => this.activate())
    owner.on?.('lost', () => { this.ready = false })
  }

  get available() { return this.ready && this.owner.owned && !this.error && !this.store.error }
  requireAvailable() { if (!this.available) { throw Object.assign(new Error(this.error || this.store.error || this.owner.error || 'Scheduling is not ready on this endpoint.'), { status: 503 }) } }

  start() {
    if (!this.timer) { this.timer = setInterval(() => this.tick(), 15000); this.timer.unref() }
    try { if (this.owner.owned) { this.activate() } else { this.owner.start() } } catch { this.error = 'Scheduling could not acquire its storage lock. Check directory access and install util-linux flock.' }
  }

  activate() {
    try { this.store.recover(); this.ready = true; this.error = null } catch { this.error = 'Schedule recovery failed. Existing files are preserved and scheduling is paused.' }
  }

  pause() { this.error = 'Schedule storage could not be updated. Scheduling is paused to prevent duplicate runs.' }

  finish(job, run, finished) {
    this.active.delete(run.runId)
    try {
      this.store.updateRun(run.runId, { status: finished.cancelled ? 'interrupted' : finished.exitCode === 0 ? 'completed' : 'failed', ...(finished.threadId ? { threadId: finished.threadId } : {}), finishedAt: this.now(), ...(finished.exitCode === 0 || finished.cancelled ? {} : { error: scheduleFailure(finished.lastError, Boolean(finished.threadId)) }) })
      if (!finished.cancelled) { this.notifications.enqueue(`scheduled:${run.runId}`, 'POST', '/notifications', { sessionId: job.originSessionId, scheduleId: job.id, runId: run.runId, title: `${job.name} ${finished.exitCode === 0 ? 'completed' : 'needs attention'}`, body: finished.exitCode === 0 ? 'Your scheduled agent finished. Open the schedule to review this run.' : scheduleFailure(finished.lastError, Boolean(finished.threadId)), kind: finished.exitCode === 0 ? 'completed' : 'failed' }) }
    } catch { this.pause() }
  }

  launch(job, run) {
    this.requireAvailable()
    if (this.runners.runners.has(run.sessionId.toLowerCase())) { this.store.updateRun(run.runId, { status: 'failed', finishedAt: this.now(), error: 'This scheduled task is already running.' }); return }
    let runner
    try {
      runner = this.runners.start({ ...job.task, sessionId: run.sessionId, prompt: job.task.prompt, images: [], existsOnServer: false, notify: false, notificationContext: { sessionId: job.originSessionId, scheduleId: job.id, runId: run.runId }, onFinish: finished => this.finish(job, run, finished) })
    } catch (error) { this.finish(job, run, { exitCode: 1, lastError: error.message }); return }
    if (!runner.hasExited) {
      this.active.set(run.runId, runner)
      try { this.store.updateRun(run.runId, { status: 'running', startedAt: this.now(), ...(runner.threadId ? { threadId: runner.threadId } : {}) }) } catch { this.pause() }
    }
  }

  runNow(id, requestId) {
    this.requireAvailable()
    const job = this.store.get(id)
    if (!job) { throw Object.assign(new Error('Schedule not found.'), { status: 404 }) }
    const existing = this.store.lookupClaim(id, `manual:${requestId}`)
    if (existing) { return existing }
    if (this.store.busy(id)) { throw Object.assign(new Error('This schedule already has an active run. Stop it or wait for it to finish.'), { status: 409 }) }
    const claimed = this.store.claim(job, `manual:${requestId}`, this.now(), job.nextRunAt)
    if (claimed.claimed) {
      this.store.updateRun(claimed.run.runId, { requestId })
      this.launch(job, claimed.run)
    }
    return this.store.state.runs.find(run => run.runId === claimed.run.runId) || claimed.run
  }

  tick() {
    if (!this.available) { return }
    try {
      for (const [id, runner] of this.active) {
        const run = this.store.state.runs.find(run => run.runId === id)
        const status = runner.requests?.size || runner.childRequests?.size ? 'waiting' : 'running'
        if (run && (run.status !== status || runner.threadId && run.threadId !== runner.threadId)) { this.store.updateRun(id, { status, ...(runner.threadId ? { threadId: runner.threadId } : {}) }) }
      }
      for (const job of this.store.state.schedules.filter(job => job.enabled && !job.deleted && job.nextRunAt <= this.now())) {
        const next = nextOccurrence(job.schedule, this.now(), job.anchorAt)
        const error = this.store.busy(job.id) ? 'Skipped because the previous run still needs to finish.' : this.now() - job.nextRunAt > this.graceMs ? 'Skipped because the endpoint missed the scheduled time.' : null
        const claim = this.store.claim(job, `scheduled:${job.nextRunAt}`, job.nextRunAt, next, error ? 'skipped' : 'starting', error)
        if (claim.claimed && !error) { this.launch(job, claim.run) }
      }
    } catch { this.pause() }
  }

  close() { clearInterval(this.timer); this.timer = null; this.ready = false; this.owner.close() }
}

const directory = path.join(process.env.CLOUDE_DATA || path.join(os.homedir(), '.cloude-agent'), 'schedules')
const owner = new ScheduleOwner(directory)
export const agentSchedules = new AgentSchedules(new ScheduleStore(directory, owner), owner, runnerManager)
