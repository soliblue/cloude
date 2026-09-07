import { basename } from 'node:path'
import { pushDelivery } from './Notifications/PushDelivery.js'
import { preparePrompt } from './ImageDropbox.js'
import Runner from './Runner.js'
import CodexRunner from './Codex/CodexRunner.js'

class RunnerManager {
  constructor() {
    this.runners = new Map()
  }

  start({ sessionId, path, prompt, images, existsOnServer, model, effort, permissionMode, provider, threadId, reviewTarget, shellCommand, skills = [], mentions = [], projectId, response, onFinish, notify = true, notificationContext }) {
    const previous = this.runners.get(sessionId.toLowerCase())
    const runner = new (provider === 'codex' ? CodexRunner : Runner)({
      sessionId,
      threadId,
      reviewTarget,
      shellCommand,
      skills,
      mentions,
      projectId,
      notificationContext,
      hasStartedBefore: existsOnServer,
      model,
      effort,
      permissionMode,
      onFinish: () => {
        onFinish?.(runner)
        if (this.runners.get(sessionId.toLowerCase()) === runner) {
          this.runners.delete(sessionId.toLowerCase())
          if (notify && !runner.cancelled) {
            pushDelivery.enqueue(`completed:${sessionId}`, 'POST', '/notifications', { sessionId, title: `${basename(path)} ${runner.exitCode === 0 ? 'completed' : 'needs attention'}`, body: runner.exitCode === 0 ? 'Your agent finished. Open the task to review the result.' : 'Your agent stopped with an error. Open the task for details.', kind: runner.exitCode === 0 ? 'completed' : 'failed' })
          }
        }
      }
    })
    this.runners.set(sessionId.toLowerCase(), runner)
    if (response) { Promise.resolve(runner.subscribe(response)).catch((error) => response.destroy(error)) }
    const begin = () => Promise.resolve(runner.spawn(path, provider === 'codex' ? prompt : preparePrompt(prompt, images, sessionId), images)).catch((error) => runner.fail(error))
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
    return runner
  }

  resumeIfExists(sessionId, afterSeq, response) {
    const runner = this.runners.get(sessionId.toLowerCase())
    if (runner) {
      Promise.resolve(runner.subscribe(response, afterSeq)).catch((error) => response.destroy(error))
      return true
    }
    return false
  }

  abort(sessionId) {
    if (this.runners.has(sessionId.toLowerCase())) {
      this.runners.get(sessionId.toLowerCase()).abort()
      return true
    }
    return false
  }
}

export const runnerManager = new RunnerManager()
