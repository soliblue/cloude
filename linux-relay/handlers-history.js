import { readdirSync, statSync } from 'fs'
import { join, basename } from 'path'
import { log } from './log.js'
import { toAppleDate, toAppleTimestamp, projectDir, parseJSONL, extractToolInput, UUID_REGEX } from './shared.js'

const EMPTY_STATS = { totalSessions: 0, totalMessages: 0, firstSessionDate: null, dailyActivity: [], modelUsage: {}, hourCounts: {}, longestSession: null }

export function handleGetUsageStats(ws, sendTo) {
  const projectsDir = join(process.env.HOME, '.claude', 'projects')
  try { readdirSync(projectsDir) } catch {
    return sendTo(ws, { type: 'usage_stats', stats: EMPTY_STATS })
  }

  try {
    let totalSessions = 0, totalMessages = 0, firstSessionDate = null
    const dailyMap = {}
    const modelUsage = {}
    const hourCounts = {}
    let longestSession = null

    for (const dir of readdirSync(projectsDir, { withFileTypes: true }).filter(d => d.isDirectory())) {
      const dirPath = join(projectsDir, dir.name)
      for (const file of readdirSync(dirPath).filter(f => f.endsWith('.jsonl'))) {
        let entries
        try { entries = parseJSONL(join(dirPath, file)) } catch { continue }

        let sessionMessages = 0
        let sessionStart = null, sessionEnd = null

        for (const entry of entries) {
          const { type, timestamp, message } = entry
          if (!type || !timestamp) continue

          if (type === 'user' || type === 'assistant') {
            totalMessages++
            sessionMessages++

            if (!sessionStart || timestamp < sessionStart) sessionStart = timestamp
            if (!sessionEnd || timestamp > sessionEnd) sessionEnd = timestamp

            const dateStr = timestamp.slice(0, 10)
            if (!firstSessionDate || dateStr < firstSessionDate) firstSessionDate = dateStr

            if (!dailyMap[dateStr]) dailyMap[dateStr] = { messageCount: 0, sessionIds: new Set(), toolCallCount: 0 }
            dailyMap[dateStr].messageCount++
            dailyMap[dateStr].sessionIds.add(file)

            hourCounts[timestamp.slice(11, 13)] = (hourCounts[timestamp.slice(11, 13)] || 0) + 1
          }

          if (type === 'assistant' && message) {
            const model = message.model
            if (model && !model.startsWith('<')) {
              const bucket = modelUsage[model] ??= { inputTokens: 0, outputTokens: 0, cacheReadInputTokens: 0, cacheCreationInputTokens: 0 }
              const usage = message.usage
              if (usage) {
                bucket.inputTokens += usage.input_tokens || 0
                bucket.outputTokens += usage.output_tokens || 0
                bucket.cacheReadInputTokens += usage.cache_read_input_tokens || 0
                bucket.cacheCreationInputTokens += usage.cache_creation_input_tokens || 0
              }
            }

            if (Array.isArray(message.content)) {
              const toolCount = message.content.filter(c => c.type === 'tool_use').length
              if (toolCount) {
                const dateStr = timestamp.slice(0, 10)
                if (dailyMap[dateStr]) dailyMap[dateStr].toolCallCount += toolCount
              }
            }
          }
        }

        if (sessionMessages > 0) {
          totalSessions++
          const duration = sessionStart && sessionEnd ? Math.round((new Date(sessionEnd) - new Date(sessionStart)) / 1000) : 0
          if (!longestSession || sessionMessages > longestSession.messageCount) {
            longestSession = { messageCount: sessionMessages, duration }
          }
        }
      }
    }

    const dailyActivity = Object.entries(dailyMap)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, data]) => ({ date, messageCount: data.messageCount, sessionCount: data.sessionIds.size, toolCallCount: data.toolCallCount }))

    log(`Usage stats: ${totalSessions} sessions, ${totalMessages} messages`)
    sendTo(ws, { type: 'usage_stats', stats: { totalSessions, totalMessages, firstSessionDate, dailyActivity, modelUsage, hourCounts, longestSession } })
  } catch (e) {
    log(`Usage stats error: ${e.message}`)
    sendTo(ws, { type: 'usage_stats', stats: EMPTY_STATS })
  }
}

export function handleListRemoteSessions(workingDirectory, ws, sendTo) {
  const dirPath = projectDir(workingDirectory)
  try {
    const files = readdirSync(dirPath).filter(f => f.endsWith('.jsonl'))
    const sessions = []

    for (const file of files) {
      const sessionId = basename(file, '.jsonl')
      if (!UUID_REGEX.test(sessionId)) continue

      const filePath = join(dirPath, file)
      const st = statSync(filePath)
      const entries = parseJSONL(filePath)
      const messageCount = entries.filter(e => e.type === 'user' || e.type === 'assistant').length

      sessions.push({ sessionId, workingDirectory, lastModified: toAppleTimestamp(st.mtime.getTime()), messageCount })
    }

    sessions.sort((a, b) => b.lastModified - a.lastModified)
    log(`Remote sessions: ${sessions.length} for ${workingDirectory}`)
    sendTo(ws, { type: 'remote_session_list', sessions })
  } catch (e) {
    log(`List sessions error: ${e.message}`)
    sendTo(ws, { type: 'remote_session_list', sessions: [] })
  }
}

export function handleSyncHistory(sessionId, workingDirectory, ws, sendTo) {
  const sessionFile = join(projectDir(workingDirectory), `${sessionId}.jsonl`)

  try {
    const entries = parseJSONL(sessionFile)
    const userMessages = []
    const assistantMessages = {}

    for (const entry of entries) {
      const { type, uuid, timestamp, message } = entry
      if (!type || !message) continue

      if (type === 'user') {
        if (typeof message.content === 'string') {
          userMessages.push({ uuid, timestamp, text: message.content })
        }
      } else if (type === 'assistant') {
        if (!Array.isArray(message.content)) continue
        const messageId = message.id || uuid
        const model = message.model || null

        for (const item of message.content) {
          if (!item.type) continue
          let contentItem = null

          if (item.type === 'text' && item.text) {
            contentItem = { type: 'text', text: item.text }
          } else if (item.type === 'tool_use' && item.name && item.id) {
            const editInfo = item.name === 'Edit' && item.input?.old_string != null && item.input?.new_string != null
              ? { oldString: item.input.old_string, newString: item.input.new_string } : null
            contentItem = { type: 'tool_use', toolName: item.name, toolId: item.id, toolInput: extractToolInput(item.name, item.input), editInfo }
          }

          if (contentItem) {
            if (!assistantMessages[messageId]) assistantMessages[messageId] = { timestamp, model, items: [] }
            assistantMessages[messageId].items.push(contentItem)
          }
        }
      }
    }

    const allMessages = []

    for (const u of userMessages) {
      const ts = toAppleDate(u.timestamp)
      allMessages.push({ timestamp: u.timestamp, msg: { isUser: true, text: u.text, timestamp: ts, toolCalls: [], serverUUID: u.uuid } })
    }

    for (const [uuid, data] of Object.entries(assistantMessages)) {
      let text = ''
      const toolCalls = []
      for (const item of data.items) {
        if (item.type === 'text') {
          text += item.text
        } else if (item.type === 'tool_use') {
          const tc = { name: item.toolName, input: item.toolInput || null, toolId: item.toolId, parentToolId: null, textPosition: text.length }
          if (item.editInfo) tc.editInfo = item.editInfo
          toolCalls.push(tc)
        }
      }
      if (text || toolCalls.length) {
        const ts = toAppleDate(data.timestamp)
        allMessages.push({ timestamp: data.timestamp, msg: { isUser: false, text, timestamp: ts, toolCalls, serverUUID: uuid, model: data.model } })
      }
    }

    allMessages.sort((a, b) => a.timestamp < b.timestamp ? -1 : 1)

    const merged = []
    for (const { msg } of allMessages) {
      const last = merged[merged.length - 1]
      if (!msg.isUser && last && !last.isUser) {
        const sep = (last.text && msg.text) ? '\n\n' : ''
        const offset = last.text.length + sep.length
        const adjustedTools = msg.toolCalls.map(t => ({ ...t, textPosition: (t.textPosition || 0) + offset }))
        last.text = last.text + sep + msg.text
        last.toolCalls = last.toolCalls.concat(adjustedTools)
      } else {
        merged.push({ ...msg })
      }
    }

    log(`History sync: ${merged.length} messages for session ${sessionId.slice(0, 8)}`)
    sendTo(ws, { type: 'history_sync', sessionId, messages: merged })
  } catch (e) {
    sendTo(ws, { type: 'history_sync_error', sessionId, error: e.message })
  }
}
