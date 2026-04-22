import { spawn } from 'node:child_process'
import { claudeCommand, spawnEnvironment } from './Runtime/ClaudeRuntime.js'

export default class Runner {
  constructor({ sessionId, hasStartedBefore, model, effort, onFinish }) {
    this.sessionId = sessionId
    this.hasExited = false
    this.hasStartedBefore = hasStartedBefore
    this.model = model
    this.effort = effort
    this.onFinish = onFinish
    this.process = null
    this.ring = []
    this.subscribers = new Set()
    this.seq = 0
    this.lineBuffer = ''
  }

  spawn(path, prompt) {
    const { executable, leadingArguments } = claudeCommand()
    const argumentsList = [
      ...leadingArguments,
      '-p',
      '--output-format',
      'stream-json',
      '--verbose',
      '--include-partial-messages',
      '--disallowedTools',
      'AskUserQuestion ExitPlanMode EnterPlanMode'
    ]
    if (this.model) {
      argumentsList.push('--model', this.model)
    }
    if (this.effort) {
      argumentsList.push('--effort', this.effort)
    }
    if (this.hasStartedBefore) {
      argumentsList.push('--resume', this.sessionId.toLowerCase())
    } else {
      argumentsList.push('--session-id', this.sessionId.toLowerCase())
    }
    this.process = spawn(executable, argumentsList, {
      cwd: path,
      env: spawnEnvironment(),
      stdio: ['pipe', 'pipe', 'pipe']
    })
    this.process.stdout.on('data', (data) => {
      this.ingest(data.toString('utf8'))
    })
    this.process.on('error', (error) => {
      this.emit({ type: 'error', message: `spawn_failed: ${error.message}` })
      this.finish(-1)
    })
    this.process.on('close', (code) => {
      this.finish(typeof code === 'number' ? code : -1)
    })
    this.process.stdin.write(prompt)
    this.process.stdin.end()
  }

  subscribe(response, afterSeq = -1) {
    response.on('close', () => {
      this.subscribers.delete(response)
    })
    response.on('error', () => {
      this.subscribers.delete(response)
    })
    for (const entry of this.ring) {
      if (entry.seq > afterSeq) {
        response.write(entry.data)
      }
    }
    if (this.hasExited) {
      response.end()
      return
    }
    this.subscribers.add(response)
  }

  abort() {
    if (this.process && this.process.exitCode === null) {
      this.emit({ type: 'aborted' })
      this.process.kill('SIGINT')
    }
  }

  ingest(chunk) {
    this.lineBuffer += chunk
    let newline = this.lineBuffer.indexOf('\n')
    while (newline !== -1) {
      const line = this.lineBuffer.slice(0, newline)
      this.lineBuffer = this.lineBuffer.slice(newline + 1)
      if (line.length !== 0) {
        let parsed = null
        try {
          parsed = JSON.parse(line)
        } catch {
          parsed = null
        }
        if (parsed) {
          this.emit({ event: parsed })
        }
      }
      newline = this.lineBuffer.indexOf('\n')
    }
  }

  emit(partial) {
    this.seq += 1
    const data = Buffer.from(
      `${JSON.stringify({ ...partial, seq: this.seq, sessionId: this.sessionId })}\n`
    )
    this.ring.push({ seq: this.seq, data })
    if (this.ring.length > 1000) {
      this.ring.splice(0, this.ring.length - 1000)
    }
    for (const subscriber of this.subscribers) {
      subscriber.write(data)
    }
  }

  finish(exitCode) {
    if (this.hasExited) {
      return
    }
    if (this.lineBuffer.trim().length !== 0) {
      let parsed = null
      try {
        parsed = JSON.parse(this.lineBuffer)
      } catch {
        parsed = null
      }
      if (parsed) {
        this.emit({ event: parsed })
      }
    }
    this.hasExited = true
    this.emit({ type: 'exit', code: exitCode })
    for (const subscriber of this.subscribers) {
      subscriber.end()
    }
    this.subscribers.clear()
    this.onFinish?.()
  }
}
