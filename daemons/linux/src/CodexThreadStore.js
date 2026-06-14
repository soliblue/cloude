import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const storePath = path.join(os.homedir(), '.config', 'remote-cc', 'codex-threads.json')

class CodexThreadStore {
  constructor() {
    this.loaded = false
    this.values = {}
  }

  threadId(sessionId) {
    this.load()
    return this.values[sessionId.toLowerCase()] || null
  }

  set(threadId, sessionId) {
    this.load()
    this.values[sessionId.toLowerCase()] = threadId
    fs.mkdirSync(path.dirname(storePath), { recursive: true })
    fs.writeFileSync(storePath, JSON.stringify(this.values, null, 2))
  }

  load() {
    if (this.loaded) {
      return
    }
    this.loaded = true
    if (fs.existsSync(storePath)) {
      this.values = JSON.parse(fs.readFileSync(storePath, 'utf8'))
    }
  }
}

export const codexThreadStore = new CodexThreadStore()
