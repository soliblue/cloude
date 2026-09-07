import fs from 'node:fs'
import path from 'node:path'
import { spawn } from 'node:child_process'
import { EventEmitter } from 'node:events'

export default class ScheduleOwner extends EventEmitter {
  constructor(directory, spawnProcess = spawn) { super(); this.spawnProcess = spawnProcess; this.directory = directory; this.owned = false; this.process = null; this.error = 'Scheduling has not started on this endpoint.' }

  start() {
    if (this.process) { return }
    fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 })
    const child = this.spawnProcess('/usr/bin/flock', ['--nonblock', '--conflict-exit-code', '75', path.join(this.directory, 'owner.lock'), '/bin/sh', '-c', 'printf "ready\\n"; cat >/dev/null'], { stdio: ['pipe', 'pipe', 'ignore'] })
    this.process = child
    let output = ''
    child.stdout.on('data', data => {
      output += data.toString()
      if (this.process === child && output === 'ready\n') { this.owned = true; this.error = null; this.emit('ready') }
    })
    const lost = () => {
      if (this.process === child) { child.stdin.destroy?.(); this.owned = false; this.process = null; this.error = 'Scheduling is unavailable. Another daemon owns this data directory or the util-linux flock command is missing.'; this.emit('lost') }
    }
    child.on('error', lost)
    child.on('exit', lost)
    child.stdin.on('error', lost)
  }

  close() { this.owned = false; this.process?.stdin.end(); this.process = null }
}
