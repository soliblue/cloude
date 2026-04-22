import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

function parsed(line) {
  try {
    return JSON.parse(line)
  } catch {
    return null
  }
}

function isUserPromptEntry(line) {
  const object = parsed(line)
  if (object?.type === 'user' && object.message) {
    if (typeof object.message.content === 'string' && object.message.content.length > 0) {
      return true
    }
    if (Array.isArray(object.message.content)) {
      return object.message.content.some((block) => block.type === 'text')
    }
  }
  return false
}

function extractLastTurn(lines) {
  let cut = 0
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    if (isUserPromptEntry(lines[index])) {
      cut = index
      break
    }
  }
  return lines.slice(cut)
}

function loadLastTurn(sessionId) {
  const projects = path.join(os.homedir(), '.claude', 'projects')
  if (fs.existsSync(projects)) {
    for (const entry of fs.readdirSync(projects, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        const file = path.join(projects, entry.name, `${sessionId}.jsonl`)
        if (fs.existsSync(file)) {
          return extractLastTurn(fs.readFileSync(file, 'utf8').split('\n').filter(Boolean))
        }
      }
    }
  }
  return null
}

export function replay(sessionId, response) {
  const lines = loadLastTurn(sessionId)
  if (lines) {
    let seq = 0
    let batch = ''
    for (const line of lines) {
      const object = parsed(line)
      if (object) {
        seq += 1
        batch += `${JSON.stringify({ event: object, seq, sessionId })}\n`
      }
    }
    batch += `${JSON.stringify({ type: 'exit', code: 0, seq: seq + 1, sessionId })}\n`
    response.end(batch)
    return true
  }
  return false
}
