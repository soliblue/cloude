import { log } from './log.js'
import { handleListDirectory, handleGetFile, handleSearchFiles } from './handlers-files.js'
import { handleGitStatus, handleGitDiff, handleGitCommit, handleGitLog } from './handlers-git.js'
import { handleSyncHistory } from './handlers-history.js'
import { handleSuggestName } from './handlers-naming.js'
import { handleTranscribe } from './handlers-transcribe.js'

export function handleMessage(msg, ws, ctx) {
  const { manager, sendTo } = ctx

  switch (msg.type) {
    case 'chat': {
      const convId = msg.conversationId || crypto.randomUUID()
      manager.run({
        prompt: msg.message,
        workingDirectory: msg.workingDirectory,
        sessionId: msg.sessionId,
        isNewSession: msg.isNewSession !== false,
        imagesBase64: msg.imagesBase64,
        filesBase64: msg.filesBase64,
        conversationId: convId,
        conversationName: msg.conversationName,
        forkSession: msg.forkSession || false,
        model: msg.model,
        effort: msg.effort
      })
      break
    }

    case 'abort':
      if (msg.conversationId) manager.abort(msg.conversationId)
      else manager.abortAll()
      break

    case 'list_directory':
      handleListDirectory(msg.path, ws, sendTo)
      break

    case 'get_file':
    case 'get_file_full_quality':
      handleGetFile(msg.path, ws, sendTo)
      break

    case 'git_status':
      handleGitStatus(msg.path, ws, sendTo)
      break

    case 'git_diff':
      handleGitDiff(msg.path, msg.file, msg.staged, ws, sendTo)
      break

    case 'git_commit':
      handleGitCommit(msg.path, msg.message, msg.files, ws, sendTo)
      break

    case 'git_log':
      handleGitLog(msg.path, msg.count || 10, ws, sendTo)
      break

    case 'search_files':
      handleSearchFiles(msg.query, msg.workingDirectory, ws, sendTo)
      break

    case 'sync_history':
      handleSyncHistory(msg.sessionId, msg.workingDirectory, ws, sendTo)
      break

    case 'suggest_name':
      handleSuggestName(msg.text, msg.context, msg.conversationId, ws, sendTo)
      break

    case 'request_missed_response':
      break

    case 'transcribe':
      handleTranscribe(msg.audioBase64, ws, sendTo)
      break

    case 'ping':
      sendTo(ws, { type: 'pong', sentAt: msg.sentAt, serverAt: Date.now() / 1000 })
      break

    default:
      log(`Unknown message type: ${msg.type}`)
  }
}
