import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import HTTPResponse from '../Networking/HTTPResponse.js'
import { codexSessions } from '../Codex/CodexSessions.js'
import { codexClient } from '../Codex/CodexClient.js'

function parsedBody(request) {
  try {
    return JSON.parse(request.body.toString('utf8'))
  } catch {
    return null
  }
}

function parsedJSON(text) {
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

function readTranscript(targetPath, sessionId) {
  const encoded = targetPath.replaceAll('/', '-').replaceAll('.', '-')
  const file = path.join(os.homedir(), '.claude', 'projects', encoded, `${sessionId.toLowerCase()}.jsonl`)
  if (fs.existsSync(file)) {
    const lines = []
    for (const raw of fs.readFileSync(file, 'utf8').split('\n')) {
      if (raw) {
        const object = parsedJSON(raw)
        if (object?.message?.role) {
          if (typeof object.message.content === 'string') {
            lines.push(`${object.message.role}: ${object.message.content}`)
          }
          if (Array.isArray(object.message.content)) {
            for (const block of object.message.content) {
              if (block.type === 'text' && typeof block.text === 'string') {
                lines.push(`${object.message.role}: ${block.text}`)
              }
            }
          }
        }
      }
    }
    return lines.join('\n\n')
  }
  return ''
}

export async function updateTitle(request, params) {
  const body = parsedBody(request)
  if (params.id && body?.path && codexSessions.read(params.id)) {
    const result = await codexClient.request('thread/read', { threadId: codexSessions.read(params.id).threadId, includeTurns: false })
    return HTTPResponse.json(200, { title: (result.thread.name || result.thread.preview || 'Codex task').split('\n')[0].slice(0, 60), symbol: 'terminal' })
  }
  if (params.id && body?.path) {
    const transcript = readTranscript(body.path, params.id)
    if (transcript) {
      return HTTPResponse.json(200, { title: transcript.split('\n')[0].replace(/^user: /u, '').slice(0, 60), symbol: 'terminal' })
    }
    return HTTPResponse.json(404, { error: 'transcript_not_found' })
  }
  return HTTPResponse.json(400, { error: 'missing_params' })
}
