import { readFileSync } from 'fs'
import { join } from 'path'

export const DEFAULT_PROJECT = process.env.CLOUDE_PROJECT || `${process.env.HOME}/projects/cloude`

export function resolveProject(workingDirectory) { return workingDirectory || DEFAULT_PROJECT }

export function sendError(ws, sendTo, e) { sendTo(ws, { type: 'error', message: e.message }) }
export const APPLE_EPOCH = 978307200

export function toAppleTimestamp(ms) { return ms / 1000 - APPLE_EPOCH }
export function toAppleDate(isoString) { return toAppleTimestamp(new Date(isoString).getTime()) }

export function projectDir(workingDirectory) {
  return join(process.env.HOME, '.claude', 'projects', workingDirectory.replace(/\//g, '-'))
}

export function parseJSONL(filePath) {
  const content = readFileSync(filePath, 'utf8')
  const entries = []
  for (const line of content.split('\n')) {
    if (!line) continue
    try { entries.push(JSON.parse(line)) } catch {}
  }
  return entries
}

export function extractToolInput(name, input) {
  if (!input) return null
  if (typeof input !== 'object') return typeof input === 'string' ? input : JSON.stringify(input)
  switch (name) {
    case 'Bash': return input.command
    case 'Read': case 'Write': case 'Edit': return input.file_path
    case 'Glob': case 'Grep': return input.pattern
    case 'WebFetch': return input.url
    case 'WebSearch': return input.query
    case 'Task': return `${input.subagent_type || 'agent'}: ${input.description || ''}`
    case 'Skill': return input.args ? `${input.skill}:${input.args}` : input.skill || null
    case 'TodoWrite': return input.todos ? JSON.stringify(input.todos) : null
    case 'TeamCreate': case 'TeamDelete': return input.team_name
    case 'SendMessage': return `${input.type || 'message'} → ${input.target || ''}`
    default: return JSON.stringify(input)
  }
}

export const MIME_TYPES = {
  '.js': 'text/javascript', '.ts': 'text/typescript', '.json': 'application/json',
  '.md': 'text/markdown', '.txt': 'text/plain', '.html': 'text/html', '.css': 'text/css',
  '.py': 'text/x-python', '.go': 'text/x-go', '.rs': 'text/x-rust', '.swift': 'text/x-swift',
  '.yaml': 'text/yaml', '.yml': 'text/yaml', '.toml': 'text/toml', '.xml': 'text/xml',
  '.sh': 'text/x-shellscript', '.sql': 'text/x-sql', '.csv': 'text/csv',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif',
  '.svg': 'image/svg+xml', '.webp': 'image/webp', '.pdf': 'application/pdf',
}

export const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
export const MAX_CHUNK = 500_000
