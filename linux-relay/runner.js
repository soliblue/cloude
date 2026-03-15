import { spawn } from 'child_process'
import { writeFileSync, mkdirSync, existsSync } from 'fs'
import { join } from 'path'
import { log } from './log.js'
import { extractToolInput } from './shared.js'

export class ClaudeCodeRunner {
  constructor(conversationId, onEvent) {
    this.conversationId = conversationId
    this.onEvent = onEvent
    this.process = null
    this.lineBuffer = ''
    this.accumulatedOutput = ''
    this.sessionId = null
    this.pendingRunStats = null
    this.superseded = false
  }

  run({ prompt, workingDirectory, sessionId, isNewSession, imagesBase64, filesBase64, forkSession, model, effort }) {
    let fullPrompt = prompt
    if (filesBase64 && filesBase64.length > 0) {
      const prefix = filesBase64.map(f => `Read the file at ${f.name}`).join('\n')
      fullPrompt = `${prefix}\n${fullPrompt}`
    }

    const args = ['--dangerously-skip-permissions', '--output-format', 'stream-json', '--verbose', '--include-partial-messages']
    if (model) args.push('--model', model)
    if (effort) args.push('--effort', effort)
    if (!isNewSession && sessionId) {
      args.push('--resume', sessionId)
      if (forkSession) args.push('--fork-session')
    } else if (isNewSession && sessionId) {
      args.push('--session-id', sessionId)
    }
    args.push('-p', fullPrompt)

    const rawCwd = workingDirectory || process.env.HOME
    const cwd = rawCwd === '~' || rawCwd.startsWith('~/') ? rawCwd.replace('~', process.env.HOME) : rawCwd
    this._cwd = cwd
    log(`Running claude in ${cwd} (conv=${this.conversationId.slice(0, 8)})`)

    const env = { ...process.env, TERM: 'xterm-256color', NO_COLOR: '1', CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: '1' }

    if (imagesBase64 && imagesBase64.length > 0) {
      const tmpDir = join(cwd, '.cloude-tmp')
      mkdirSync(tmpDir, { recursive: true })
      const imagePaths = imagesBase64.map((b64, i) => {
        const p = join(tmpDir, `image-${i}.png`)
        writeFileSync(p, Buffer.from(b64, 'base64'))
        return p
      })
      const prefix = imagePaths.map(p => `First, read the image at ${p}`).join('\n')
      args[args.length - 1] = `${prefix}\n${args[args.length - 1]}`
    }

    this.process = spawn('claude', args, { cwd, env })
    this.process.stdin.end()

    this.process.on('error', (err) => {
      log(`Process spawn error: ${err.message}`)
      this.onEvent({ type: 'output', text: `Error: ${err.message}`, conversationId: this.conversationId })
      this.onEvent({ type: 'status', state: 'idle', conversationId: this.conversationId })
    })

    this.onEvent({ type: 'status', state: 'running', conversationId: this.conversationId })

    this.process.stdout.on('data', (data) => this.processData(data.toString()))
    this.process.stderr.on('data', (data) => {
      this.onEvent({ type: 'output', text: data.toString(), conversationId: this.conversationId })
    })

    this.process.on('close', (code) => {
      if (this.lineBuffer.trim()) this.processLine(this.lineBuffer)
      if (!this.superseded) {
        if (this.pendingRunStats) {
          this.onEvent({ ...this.pendingRunStats, conversationId: this.conversationId })
          this.pendingRunStats = null
        }
        this.onEvent({ type: 'status', state: 'idle', conversationId: this.conversationId })
      }
      log(`Claude exited with code ${code}${this.superseded ? ' (superseded)' : ''} (conv=${this.conversationId.slice(0, 8)})`)
    })
  }

  processData(data) {
    this.lineBuffer += data
    const lines = this.lineBuffer.split('\n')
    this.lineBuffer = lines.pop()
    for (const line of lines) {
      if (line.trim()) this.processLine(line)
    }
  }

  processLine(line) {
    let json
    try { json = JSON.parse(line) } catch { return }

    if (json.type === 'stream_event' && json.event) {
      json = { ...json.event, session_id: json.session_id, parent_tool_use_id: json.parent_tool_use_id, uuid: json.uuid }
    }

    const type = json.type
    const cid = this.conversationId

    if (type === 'system') {
      if (json.subtype === 'init' && json.session_id) {
        this.sessionId = json.session_id
        this.onEvent({ type: 'session_id', id: json.session_id, conversationId: cid })
        if (json.model) this.model = json.model
      }
      if (json.subtype === 'status' && json.status === 'compacting') {
        this.onEvent({ type: 'status', state: 'compacting', conversationId: cid })
      }
      return
    }

    if (type === 'content_block_delta') {
      const text = json.delta?.text
      if (text) {
        this.accumulatedOutput += text
        this.onEvent({ type: 'output', text, conversationId: cid })
      }
      return
    }

    if (type === 'assistant' && json.message?.content) {
      for (const block of json.message.content) {
        if (block.type === 'tool_use') {
          const inputStr = extractToolInput(block.name, block.input)
          const event = {
            type: 'tool_call',
            name: block.name,
            input: inputStr,
            toolId: block.id,
            parentToolId: json.parent_tool_use_id || null,
            conversationId: cid,
            textPosition: this.accumulatedOutput.length
          }
          if (block.name === 'Edit' && block.input?.old_string != null && block.input?.new_string != null) {
            event.editInfo = { oldString: block.input.old_string, newString: block.input.new_string }
          }
          this.onEvent(event)
        }
      }
      if (json.uuid) {
        this.onEvent({ type: 'message_uuid', uuid: json.uuid, conversationId: cid })
      }
      return
    }

    if (type === 'user' && json.message?.content) {
      const content = json.message.content
      if (Array.isArray(content)) {
        for (const block of content) {
          if (block.type === 'tool_result' && block.tool_use_id) {
            let output = ''
            let summary = ''
            if (typeof block.content === 'string') {
              output = block.content.slice(0, 5000)
              summary = block.content.split('\n')[0].slice(0, 80)
            } else if (Array.isArray(block.content)) {
              const textParts = block.content.filter(c => c.type === 'text').map(c => c.text)
              output = textParts.join('\n').slice(0, 5000)
              summary = (textParts[0] || '').split('\n')[0].slice(0, 80)
            }
            this.onEvent({ type: 'tool_result', toolId: block.tool_use_id, summary, output, conversationId: cid })

          }
        }
      } else if (typeof content === 'string') {
        const match = content.match(/<local-command-stdout>([\s\S]*?)<\/local-command-stdout>/)
        if (match) {
          this.onEvent({ type: 'output', text: match[1], conversationId: cid })
        }
      }
      return
    }

    if (type === 'result') {
      if (json.session_id) this.sessionId = json.session_id
      this.pendingRunStats = {
        type: 'run_stats',
        durationMs: json.duration_ms || 0,
        costUsd: json.total_cost_usd || 0,
        model: json.model || this.model || null
      }
      return
    }
  }

  abort({ supersede = false } = {}) {
    if (!this.process) return Promise.resolve()
    if (supersede) this.superseded = true
    return new Promise((resolve) => {
      this.process.on('close', resolve)
      this.process.kill('SIGINT')
      setTimeout(() => {
        if (this.process && this.process.exitCode === null) this.process.kill('SIGTERM')
      }, 2000)
      setTimeout(() => {
        if (this.process && this.process.exitCode === null) this.process.kill('SIGKILL')
        resolve()
      }, 5000)
    })
  }
}

export class RunnerManager {
  constructor() {
    this.runners = new Map()
    this.broadcast = null
  }

  setBroadcast(fn) { this.broadcast = fn }

  async run(opts) {
    const convId = opts.conversationId || crypto.randomUUID()
    const existing = this.runners.get(convId)
    if (existing && existing.runner.process && existing.runner.process.exitCode === null) {
      await existing.runner.abort({ supersede: true })
    }

    const runner = new ClaudeCodeRunner(convId, (event) => {
      if (this.broadcast) this.broadcast(event)
    })

    this.runners.set(convId, { runner, sessionId: opts.sessionId || null })
    runner.run(opts)

    runner.process.on('close', () => {
      const entry = this.runners.get(convId)
      if (entry) entry.sessionId = runner.sessionId
      setTimeout(() => this.runners.delete(convId), 300000)
    })
  }

  async abort(conversationId) {
    const entry = this.runners.get(conversationId)
    if (entry && entry.runner.process && entry.runner.process.exitCode === null) {
      await entry.runner.abort()
    } else if (this.broadcast) {
      this.broadcast({ type: 'status', state: 'idle', conversationId })
    }
  }

  abortAll() {
    for (const [convId, entry] of this.runners) {
      if (entry.runner.process) {
        entry.runner.abort()
      } else if (this.broadcast) {
        this.broadcast({ type: 'status', state: 'idle', conversationId: convId })
      }
    }
  }

  getSessionId(conversationId) {
    return this.runners.get(conversationId)?.runner?.sessionId || this.runners.get(conversationId)?.sessionId
  }

  getProcessInfo() {
    const procs = []
    for (const [convId, entry] of this.runners) {
      if (entry.runner.process && !entry.runner.process.killed) {
        procs.push({
          pid: entry.runner.process.pid,
          command: 'claude',
          startTime: null,
          conversationId: convId,
          conversationName: null
        })
      }
    }
    return procs
  }
}
