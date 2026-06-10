import fs from 'node:fs'
import path from 'node:path'
import HTTPResponse from '../Networking/HTTPResponse.js'
import { transcriptionReady } from './TranscribeHandler.js'

function resolved(filePath) {
  return filePath.startsWith('~/')
    ? path.join(process.env.HOME || '', filePath.slice(2))
    : filePath === '~'
      ? process.env.HOME || ''
      : path.resolve(filePath)
}

function keyValue(line) {
  const colon = line.indexOf(':')
  if (colon === -1) {
    return null
  }
  const key = line.slice(0, colon).trim()
  let value = line.slice(colon + 1).trim()
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    value = value.slice(1, -1)
  }
  return key ? [key, value] : null
}

function frontmatter(content) {
  const result = {}
  let started = false
  let inMetadata = false
  for (const line of content.split('\n')) {
    if (line === '---') {
      if (started) {
        break
      }
      started = true
      continue
    }
    if (!started) {
      continue
    }
    if (line.startsWith('  ')) {
      if (inMetadata) {
        const pair = keyValue(line.trim())
        if (pair) {
          result[pair[0]] = pair[1]
        }
      }
      continue
    }
    inMetadata = false
    const pair = keyValue(line)
    if (pair) {
      if (pair[0] === 'metadata' && pair[1] === '') {
        inMetadata = true
      } else {
        result[pair[0]] = pair[1]
      }
    }
  }
  return result
}

function read(file) {
  try {
    return fs.readFileSync(file, 'utf8')
  } catch {
    return null
  }
}

function skills(root) {
  const dir = path.join(root, '.claude', 'skills')
  let entries = []
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true })
  } catch {
    return []
  }
  const result = []
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
    const file = entry.isDirectory() ? path.join(dir, entry.name, 'SKILL.md') : path.join(dir, entry.name)
    if (!entry.isDirectory() && !entry.name.endsWith('.md')) {
      continue
    }
    const content = read(file)
    if (content) {
      const meta = frontmatter(content)
      if (meta.name && meta.description && meta['user-invocable'] !== 'false') {
        result.push({ name: meta.name, description: meta.description, icon: meta.icon || 'hammer.circle' })
      }
    }
  }
  return result
}

function agents(root) {
  const dir = path.join(root, '.claude', 'agents')
  let entries = []
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true })
  } catch {
    return []
  }
  const result = []
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
    if (!entry.name.endsWith('.md')) {
      continue
    }
    const content = read(path.join(dir, entry.name))
    if (content) {
      const meta = frontmatter(content)
      if (meta.name && meta.description) {
        result.push({ name: meta.name, description: meta.description })
      }
    }
  }
  return result
}

export function manifest(request) {
  if (request.query.path) {
    const root = resolved(request.query.path)
    return HTTPResponse.json(200, {
      skills: skills(root),
      agents: agents(root),
      transcription: transcriptionReady()
    })
  }
  return HTTPResponse.json(400, { error: 'missing_path' })
}
