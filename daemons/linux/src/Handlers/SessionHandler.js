import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawnSync } from 'node:child_process'
import HTTPResponse from '../Networking/HTTPResponse.js'
import { claudeCommand, spawnEnvironment } from '../Runtime/ClaudeRuntime.js'

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
  const file = path.join(os.homedir(), '.claude', 'projects', encoded, `${sessionId}.jsonl`)
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

function parseJSONBlock(text) {
  const direct = parsedJSON(text.trim())
  if (direct) {
    return direct
  }
  const start = text.indexOf('{')
  const end = text.lastIndexOf('}')
  if (start !== -1 && end !== -1 && start < end) {
    return parsedJSON(text.slice(start, end + 1))
  }
  return null
}

function runSonnet(prompt) {
  const { executable, leadingArguments } = claudeCommand()
  const result = spawnSync(
    executable,
    [...leadingArguments, '-p', '--model', 'sonnet', '--output-format', 'json'],
    {
      env: spawnEnvironment(),
      encoding: 'utf8',
      input: prompt
    }
  )
  if (!result.error && result.status === 0) {
    return result.stdout || ''
  }
  return null
}

export function updateTitle(request, params) {
  const body = parsedBody(request)
  if (params.id && body?.path) {
    const transcript = readTranscript(body.path, params.id)
    if (transcript) {
      const output = runSonnet(`You are naming a chat window in a mobile app. The user needs to glance at the name and instantly know what this conversation is about.

Conversation:
${transcript}

Suggest a short conversation title (1-3 words) that describes what's being worked on or discussed. Be specific and descriptive, not generic or catchy. Good examples: "Auth Bug Fix", "Dark Mode", "Rename Logic", "Memory System". Bad examples: "Spark", "New Chat", "Quick Fix".

Also pick an SF Symbol name that best fits the topic. Pick something specific and creative, not generic. Prefer outline versions (e.g. "star" over "star.fill") unless only a .fill variant exists.

Respond with ONLY a JSON object and nothing else: {"title": "Short Title", "symbol": "sf.symbol.name"}`)
      const outer = output ? parsedJSON(output) : null
      const parsed = outer?.result ? parseJSONBlock(outer.result) : output ? parseJSONBlock(output) : null
      if (parsed?.title && parsed?.symbol) {
        return HTTPResponse.json(200, { title: parsed.title, symbol: parsed.symbol })
      }
      return HTTPResponse.json(500, { error: 'generation_failed' })
    }
    return HTTPResponse.json(404, { error: 'transcript_not_found' })
  }
  return HTTPResponse.json(400, { error: 'missing_params' })
}
