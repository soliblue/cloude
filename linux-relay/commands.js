import { readFileSync, writeFileSync, existsSync } from 'fs'
import { join } from 'path'
import { log } from './log.js'

export function handleCloudeCommand(command, conversationId, broadcast, workingDirectory) {
  const rest = command.slice(7)
  const spaceIdx = rest.indexOf(' ')
  const action = spaceIdx === -1 ? rest : rest.slice(0, spaceIdx)
  const args = spaceIdx === -1 ? '' : rest.slice(spaceIdx + 1)

  switch (action) {
    case 'rename':
      if (conversationId && args) {
        broadcast({ type: 'rename_conversation', name: args, conversationId })
        log(`Renamed ${conversationId.slice(0, 8)} to '${args}'`)
      }
      break

    case 'symbol':
      if (conversationId) {
        broadcast({ type: 'set_conversation_symbol', symbol: args || null, conversationId })
        log(`Set symbol for ${conversationId.slice(0, 8)} to '${args}'`)
      }
      break

    case 'memory':
      handleMemory(args, conversationId, broadcast, workingDirectory)
      break

    case 'skip':
      broadcast({ type: 'heartbeat_skipped', conversationId })
      break

    case 'delete':
      if (conversationId) broadcast({ type: 'delete_conversation', conversationId })
      break

    case 'notify':
      if (args) broadcast({ type: 'notify', title: null, body: args, conversationId })
      break

    case 'clipboard':
      if (args) broadcast({ type: 'clipboard', text: args })
      break

    case 'open':
      if (args) broadcast({ type: 'open_url', url: args })
      break

    case 'haptic':
      broadcast({ type: 'haptic', style: args || 'medium' })
      break

    case 'speak':
      if (args) broadcast({ type: 'speak', text: args })
      break

    case 'switch':
      if (args) broadcast({ type: 'switch_conversation', conversationId: args })
      break

    case 'ask':
      if (args) {
        const questions = parseAskCommand(args)
        if (questions.length) broadcast({ type: 'question', questions, conversationId })
      }
      break

    case 'screenshot':
      broadcast({ type: 'screenshot', conversationId })
      break

    case 'schedule':
      if (args) handleScheduleCommand(args, conversationId, broadcast)
      break

    default:
      log(`Unknown cloude command: ${action}`)
  }
}

function handleMemory(args, conversationId, broadcast, workingDirectory) {
  const parts = args.split(' ')
  if (parts.length < 3) return

  const target = parts[0].toLowerCase()
  const section = parts[1]
  const text = parts.slice(2).join(' ')

  let filePath
  if (target === 'local') {
    filePath = join(workingDirectory, 'CLAUDE.local.md')
  } else if (target === 'project') {
    filePath = join(workingDirectory, 'CLAUDE.md')
  } else return

  let content = ''
  try { content = readFileSync(filePath, 'utf8') } catch {}

  const sectionHeader = `## ${section}`
  const idx = content.indexOf(sectionHeader)
  if (idx !== -1) {
    const nextSection = content.indexOf('\n## ', idx + sectionHeader.length)
    const insertAt = nextSection !== -1 ? nextSection : content.length
    content = content.slice(0, insertAt).trimEnd() + '\n- ' + text + '\n' + content.slice(insertAt)
  } else {
    content = content.trimEnd() + `\n\n${sectionHeader}\n- ${text}\n`
  }

  writeFileSync(filePath, content)
  broadcast({ type: 'memory_added', target, section, text, conversationId })
  log(`Memory added to ${target}/${section}: ${text.slice(0, 50)}`)
}

function parseAskCommand(args) {
  if (args.startsWith('--questions ')) return parseQuestionsJSON(args.slice(12))
  if (args.startsWith('--q ')) return parseSimpleQuestion(args)
  return parseQuestionsJSON(args)
}

function parseQuestionsJSON(jsonStr) {
  let cleaned = jsonStr.trim()
  if ((cleaned.startsWith("'") && cleaned.endsWith("'")) || (cleaned.startsWith('"') && cleaned.endsWith('"'))) {
    cleaned = cleaned.slice(1, -1)
  }
  try {
    const decoded = JSON.parse(cleaned)
    return decoded.map(q => ({
      id: crypto.randomUUID(),
      text: q.q,
      options: (q.options || []).map(opt => {
        if (typeof opt === 'object') return { id: crypto.randomUUID(), label: opt.label || '', description: opt.desc || opt.description || null }
        const parts = String(opt).split(':')
        if (parts.length >= 2) return { id: crypto.randomUUID(), label: parts[0], description: parts.slice(1).join(':') }
        return { id: crypto.randomUUID(), label: String(opt), description: null }
      }),
      multiSelect: q.multi || false
    }))
  } catch { return [] }
}

function parseSimpleQuestion(args) {
  let questionText = '', optionsStr = '', multi = false
  const parts = args.split(' --')
  for (const part of parts) {
    const trimmed = part.startsWith('-') ? part.replace(/^-+/, '') : part
    if (trimmed.startsWith('q ')) questionText = trimmed.slice(2).replace(/^"|"$/g, '')
    else if (trimmed.startsWith('options ')) optionsStr = trimmed.slice(8).replace(/^"|"$/g, '')
    else if (trimmed === 'multi') multi = true
  }
  if (!questionText || !optionsStr) return []
  const options = optionsStr.split(',').map(opt => {
    const parts = opt.split(':')
    if (parts.length >= 2) return { id: crypto.randomUUID(), label: parts[0].trim(), description: parts.slice(1).join(':').trim() }
    return { id: crypto.randomUUID(), label: opt.trim(), description: null }
  })
  return [{ id: crypto.randomUUID(), text: questionText, options, multiSelect: multi }]
}

function handleScheduleCommand(args, conversationId, broadcast) {
  log(`Schedule command not yet implemented on Linux agent: ${args}`)
}
