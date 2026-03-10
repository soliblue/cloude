import { log } from './log.js'
import { handleListDirectory, handleGetFile, handleSearchFiles } from './handlers-files.js'
import { handleGitStatus, handleGitDiff, handleGitCommit } from './handlers-git.js'
import { handleGetUsageStats, handleListRemoteSessions, handleSyncHistory } from './handlers-history.js'
import { handleGetMemories, handleGetPlans, handleDeletePlan } from './handlers-plans.js'
import { handleSuggestName } from './handlers-naming.js'
import { handleTranscribe, handleTerminalExec } from './handlers-terminal.js'

export function handleMessage(msg, ws, ctx) {
  const { manager, broadcast, sendTo } = ctx

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
      handleGitDiff(msg.path, msg.file, ws, sendTo)
      break

    case 'git_commit':
      handleGitCommit(msg.path, msg.message, msg.files, ws, sendTo)
      break

    case 'get_memories':
      handleGetMemories(msg.workingDirectory, ws, sendTo)
      break

    case 'get_processes':
      sendTo(ws, { type: 'process_list', processes: manager.getProcessInfo() })
      break

    case 'kill_process':
      try { process.kill(msg.pid, 'SIGTERM') } catch {}
      sendTo(ws, { type: 'process_list', processes: manager.getProcessInfo() })
      break

    case 'kill_all_processes':
      manager.abortAll()
      broadcast({ type: 'process_list', processes: [] })
      break

    case 'search_files':
      handleSearchFiles(msg.query, msg.workingDirectory, ws, sendTo)
      break

    case 'get_plans':
      handleGetPlans(msg.workingDirectory, ws, sendTo)
      break

    case 'delete_plan':
      handleDeletePlan(msg.stage, msg.filename, msg.workingDirectory, ws, sendTo)
      break

    case 'get_usage_stats':
      handleGetUsageStats(ws, sendTo)
      break

    case 'set_heartbeat_interval':
    case 'get_heartbeat_config':
    case 'mark_heartbeat_read':
    case 'trigger_heartbeat':
      sendTo(ws, { type: 'heartbeat_config', intervalMinutes: null, unreadCount: 0 })
      break

    case 'sync_history':
      handleSyncHistory(msg.sessionId, msg.workingDirectory, ws, sendTo)
      break

    case 'list_remote_sessions':
      handleListRemoteSessions(msg.workingDirectory, ws, sendTo)
      break

    case 'suggest_name':
      handleSuggestName(msg.text, msg.context, msg.conversationId, ws, sendTo)
      break

    case 'request_missed_response':
      break

    case 'transcribe':
      handleTranscribe(msg.audioBase64, ws, sendTo)
      break

    case 'terminal_exec':
      handleTerminalExec(msg.command, msg.workingDirectory, ws, sendTo)
      break

    default:
      log(`Unknown message type: ${msg.type}`)
  }
}
