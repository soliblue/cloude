import { preparePrompt } from './ImageDropbox.js'
import Runner from './Runner.js'

class RunnerManager {
  constructor() {
    this.runners = new Map()
  }

  start({ sessionId, path, prompt, images, existsOnServer, model, effort, response }) {
    const previous = this.runners.get(sessionId)
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
    const begin = () => runner.spawn(path, preparePrompt(prompt, images, sessionId))
    if (previous && !previous.hasExited) {
      const previousFinish = previous.onFinish
      previous.onFinish = () => {
        previousFinish?.()
        begin()
      }
      previous.abort()
    } else {
      begin()
    }
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
