import { preparePrompt } from './ImageDropbox.js'
import Runner from './Runner.js'

class RunnerManager {
  constructor() {
    this.runners = new Map()
  }

  start({ sessionId, path, prompt, images, existsOnServer, model, effort, response }) {
    if (this.runners.has(sessionId)) {
      this.runners.get(sessionId).abort()
    }
    const runner = new Runner({
      sessionId,
      hasStartedBefore: existsOnServer,
      model,
      effort,
      onFinish: () => {
        if (this.runners.get(sessionId) === runner) {
          this.runners.delete(sessionId)
        }
      }
    })
    this.runners.set(sessionId, runner)
    runner.subscribe(response)
    runner.spawn(path, preparePrompt(prompt, images))
  }

  hasRunner(sessionId) {
    return this.runners.has(sessionId)
  }

  resume(sessionId, afterSeq, response) {
    if (this.runners.has(sessionId)) {
      this.runners.get(sessionId).subscribe(response, afterSeq)
    } else {
      response.end()
    }
  }

  abort(sessionId) {
    if (this.runners.has(sessionId)) {
      this.runners.get(sessionId).abort()
      return true
    }
    return false
  }
}

export const runnerManager = new RunnerManager()
