import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { createHash } from 'node:crypto'

export default class CodexSessions {
  constructor(directory = process.env.CLOUDE_CODEX_STATE_DIR || path.join(process.env.CLOUDE_DATA || path.join(os.homedir(), '.cloude-agent'), 'codex')) {
    this.directory = directory
    this.mutations = new Set()
    this.steering = new Map()
    this.forks = new Map()
  }

  reserve(sessionId) {
    const key = sessionId.toLowerCase()
    if (this.mutations.has(key)) { return false }
    this.mutations.add(key)
    return true
  }

  release(sessionId) {
    this.mutations.delete(sessionId.toLowerCase())
  }

  busy(sessionId) {
    return this.mutations.has(sessionId.toLowerCase())
  }

  file(sessionId, extension) {
    return path.join(this.directory, `${createHash('sha256').update(sessionId.toLowerCase()).digest('hex')}.${extension}`)
  }

  read(sessionId) {
    return fs.existsSync(this.file(sessionId, 'json')) ? JSON.parse(fs.readFileSync(this.file(sessionId, 'json'), 'utf8')) : null
  }

  write(sessionId, value) {
    this.persist(this.file(sessionId, 'json'), value)
  }

  persist(file, value, exclusive = false) {
    const created = fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 })
    const descriptor = fs.openSync(exclusive ? file : `${file}.tmp`, exclusive ? 'wx' : 'w', 0o600)
    try {
      fs.writeFileSync(descriptor, JSON.stringify(value))
      fs.fsyncSync(descriptor)
    } finally { fs.closeSync(descriptor) }
    if (!exclusive) { fs.renameSync(`${file}.tmp`, file) }
    const directory = fs.openSync(this.directory, 'r')
    try { fs.fsyncSync(directory) } finally { fs.closeSync(directory) }
    if (created) {
      let parent = path.dirname(this.directory)
      while (true) {
        const descriptor = fs.openSync(parent, 'r')
        try { fs.fsyncSync(descriptor) } finally { fs.closeSync(descriptor) }
        if (parent === path.dirname(created)) { break }
        parent = path.dirname(parent)
      }
    }
  }

  forkReceipt(sessionId, fingerprint) {
    const file = this.file(sessionId, 'fork.json')
    const receipt = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null
    if (receipt && (receipt.fingerprint !== fingerprint || !['pending', 'completed'].includes(receipt.status))) { throw new Error('This side-chat attempt belongs to a different source or directory, or its saved record is invalid.') }
    return receipt
  }

  reset(sessionId) {
    fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 })
    fs.writeFileSync(this.file(sessionId, 'jsonl'), '', { mode: 0o600 })
  }

  append(sessionId, data) {
    fs.appendFileSync(this.file(sessionId, 'jsonl'), data, { mode: 0o600 })
  }

  steeringReceipt(sessionId, requestId, prompt) {
    const file = this.file(sessionId, `steer-${requestId.toLowerCase()}.json`)
    const receipt = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null
    if (receipt && receipt.fingerprint !== createHash('sha256').update(prompt).digest('hex')) { throw new Error('This steering request ID was already used for another message.') }
    return receipt
  }

  async steer(sessionId, requestId, prompt, perform) {
    const file = this.file(sessionId, `steer-${requestId.toLowerCase()}.json`)
    const receipt = this.steeringReceipt(sessionId, requestId, prompt)
    if (this.steering.has(file)) { return this.steering.get(file) }
    if (receipt?.status === 'accepted') { return }
    if (receipt) { throw new Error('This steering request was already attempted. Refresh task history before sending another message.') }
    fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 })
    const claim = { fingerprint: createHash('sha256').update(prompt).digest('hex'), status: 'pending' }
    const descriptor = fs.openSync(file, 'wx', 0o600)
    try {
      fs.writeFileSync(descriptor, JSON.stringify(claim))
      fs.fsyncSync(descriptor)
    } finally { fs.closeSync(descriptor) }
    const directory = fs.openSync(this.directory, 'r')
    try { fs.fsyncSync(directory) } finally { fs.closeSync(directory) }
    const outcome = Promise.resolve().then(perform).then(() => {
      const descriptor = fs.openSync(`${file}.tmp`, 'w', 0o600)
      try {
        fs.writeFileSync(descriptor, JSON.stringify({ ...claim, status: 'accepted' }))
        fs.fsyncSync(descriptor)
      } finally { fs.closeSync(descriptor) }
      fs.renameSync(`${file}.tmp`, file)
    }).finally(() => this.steering.delete(file))
    this.steering.set(file, outcome)
    return outcome
  }

  replay(sessionId, response) {
    if (fs.existsSync(this.file(sessionId, 'jsonl'))) {
      response.write(`${JSON.stringify({ type: 'replay', seq: 0, sessionId })}\n`)
      const stream = fs.createReadStream(this.file(sessionId, 'jsonl'), { encoding: 'utf8' })
      let tail = ''
      stream.on('data', (chunk) => {
        tail += chunk
        const newline = tail.lastIndexOf('\n', tail.length - 2)
        if (newline !== -1) { tail = tail.slice(newline + 1) }
      })
      response.once('close', () => stream.destroy())
      stream.on('error', (error) => response.destroy(error))
      stream.on('end', () => {
        Promise.resolve().then(() => {
          const lastEvent = tail.trim() ? JSON.parse(tail) : { seq: 0 }
          if (lastEvent.type !== 'exit') {
            response.write(`${JSON.stringify({ type: 'error', message: 'Daemon restarted during this turn. Send a message to resume the saved Codex conversation.', seq: lastEvent.seq + 1, sessionId })}\n`)
            response.write(`${JSON.stringify({ type: 'exit', code: 1, seq: lastEvent.seq + 2, sessionId })}\n`)
          }
          response.end()
        }).catch((error) => response.destroy(error))
      })
      stream.pipe(response, { end: false })
      return true
    }
    return false
  }

}

export const codexSessions = new CodexSessions()
