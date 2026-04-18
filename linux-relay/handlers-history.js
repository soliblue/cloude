import { join } from 'path'
import { log } from './log.js'
import { toAppleDate, projectDir, parseJSONL, extractToolInput } from './shared.js'

export function handleSyncHistory(sessionId, workingDirectory, ws, sendTo) {
  const sessionFile = join(projectDir(workingDirectory), `${sessionId}.jsonl`)

  try {
    const entries = parseJSONL(sessionFile)
    const userMessages = []
    const assistantMessages = {}
    const toolResults = {}

    for (const entry of entries) {
      const { type, uuid, timestamp, message } = entry
      if (!type || !message) continue

      if (type === 'user') {
        if (typeof message.content === 'string') {
          userMessages.push({ uuid, timestamp, text: message.content })
        } else if (Array.isArray(message.content)) {
          for (const item of message.content) {
            if (item.type === 'tool_result' && item.tool_use_id) {
              let output = ''
              if (typeof item.content === 'string') {
                output = item.content
              } else if (Array.isArray(item.content)) {
                output = item.content.filter(p => p.type === 'text').map(p => p.text).join('\n')
              }
              if (output) toolResults[item.tool_use_id] = output.slice(0, 5000)
            }
          }
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
          if (toolResults[item.toolId]) tc.resultContent = toolResults[item.toolId]
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
