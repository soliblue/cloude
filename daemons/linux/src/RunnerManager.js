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

  resumeIfExists(sessionId, afterSeq, response) {
    const runner = this.runners.get(sessionId)
    if (runner) {
      runner.subscribe(response, afterSeq)
      return true
    }
    return false
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
