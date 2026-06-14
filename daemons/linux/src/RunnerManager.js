import { materializeImages, promptWithImagePaths } from './ImageDropbox.js'
import CodexRunner from './CodexRunner.js'
import Runner from './Runner.js'

class RunnerManager {
  constructor() {
    this.runners = new Map()
  }

  start({ sessionId, path, prompt, images, existsOnServer, provider, model, effort, permissionMode, response }) {
    const previous = this.runners.get(sessionId)
    const useCodex = provider === 'codex' || model?.startsWith('gpt-')
    const runner = new (useCodex ? CodexRunner : Runner)({
      sessionId,
      hasStartedBefore: existsOnServer,
      model,
      effort,
      permissionMode,
      onFinish: () => {
        if (this.runners.get(sessionId) === runner) {
          this.runners.delete(sessionId)
        }
      }
    })
    this.runners.set(sessionId, runner)
    runner.subscribe(response)
    const imagePaths = materializeImages(images, sessionId)
    const begin = () => {
      if (useCodex) {
        runner.spawn(path, prompt, imagePaths)
      } else {
        runner.spawn(path, promptWithImagePaths(prompt, imagePaths))
      }
    }
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
