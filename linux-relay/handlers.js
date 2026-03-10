import { readdirSync, readFileSync, statSync, existsSync, unlinkSync } from 'fs'
import { join, extname, basename } from 'path'
import { execSync, spawn } from 'child_process'
import { log } from './log.js'

const MIME_TYPES = {
  '.js': 'text/javascript', '.ts': 'text/typescript', '.json': 'application/json',
  '.md': 'text/markdown', '.txt': 'text/plain', '.html': 'text/html', '.css': 'text/css',
  '.py': 'text/x-python', '.go': 'text/x-go', '.rs': 'text/x-rust', '.swift': 'text/x-swift',
  '.yaml': 'text/yaml', '.yml': 'text/yaml', '.toml': 'text/toml', '.xml': 'text/xml',
  '.sh': 'text/x-shellscript', '.sql': 'text/x-sql', '.csv': 'text/csv',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif',
  '.svg': 'image/svg+xml', '.webp': 'image/webp', '.pdf': 'application/pdf',
}

const MAX_CHUNK = 500_000
const APPLE_EPOCH = 978307200
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const EMPTY_STATS = { totalSessions: 0, totalMessages: 0, firstSessionDate: null, dailyActivity: [], modelUsage: {}, hourCounts: {}, longestSession: null }

function toAppleTimestamp(ms) { return ms / 1000 - APPLE_EPOCH }
function toAppleDate(isoString) { return toAppleTimestamp(new Date(isoString).getTime()) }
function projectDir(workingDirectory) {
  return join(process.env.HOME, '.claude', 'projects', workingDirectory.replace(/\//g, '-'))
}
function parseJSONL(filePath) {
  const content = readFileSync(filePath, 'utf8')
  const entries = []
  for (const line of content.split('\n')) {
    if (!line) continue
    try { entries.push(JSON.parse(line)) } catch {}
  }
  return entries
}

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
    case 'request_suggestions':
    case 'get_scheduled_tasks':
    case 'toggle_scheduled_task':
    case 'delete_scheduled_task':
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

function handleListDirectory(dirPath, ws, sendTo) {
  const resolved = dirPath === '~' || !dirPath ? process.env.HOME : dirPath.replace(/^~/, process.env.HOME)
  try {
    const items = readdirSync(resolved, { withFileTypes: true })
    const entries = items.filter(d => !d.name.startsWith('.')).map(d => {
      const fullPath = join(resolved, d.name)
      try {
        const st = statSync(fullPath)
        return {
          name: d.name,
          path: fullPath,
          isDirectory: d.isDirectory(),
          size: st.size,
          modified: toAppleTimestamp(st.mtime.getTime()),
          mimeType: d.isDirectory() ? null : (MIME_TYPES[extname(d.name)] || 'application/octet-stream')
        }
      } catch {
        return { name: d.name, path: fullPath, isDirectory: d.isDirectory(), size: 0, modified: toAppleTimestamp(Date.now()), mimeType: null }
      }
    })
    entries.sort((a, b) => {
      if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1
      return a.name.localeCompare(b.name)
    })
    sendTo(ws, { type: 'directory_listing', path: resolved, entries })
  } catch (e) {
    sendTo(ws, { type: 'error', message: e.message })
  }
}

function handleGetFile(filePath, ws, sendTo) {
  try {
    const st = statSync(filePath)
    if (st.isDirectory()) return handleListDirectory(filePath, ws, sendTo)

    const data = readFileSync(filePath)
    const mimeType = MIME_TYPES[extname(filePath)] || 'application/octet-stream'
    const b64 = data.toString('base64')

    if (b64.length > MAX_CHUNK) {
      const totalChunks = Math.ceil(b64.length / MAX_CHUNK)
      for (let i = 0; i < totalChunks; i++) {
        sendTo(ws, {
          type: 'file_chunk',
          path: filePath,
          chunkIndex: i,
          totalChunks,
          data: b64.slice(i * MAX_CHUNK, (i + 1) * MAX_CHUNK),
          mimeType,
          size: st.size
        })
      }
    } else {
      sendTo(ws, { type: 'file_content', path: filePath, data: b64, mimeType, size: st.size, truncated: false })
    }
  } catch (e) {
    sendTo(ws, { type: 'error', message: e.message })
  }
}

function handleGitStatus(path, ws, sendTo) {
  try {
    const branch = execSync('git rev-parse --abbrev-ref HEAD', { cwd: path, encoding: 'utf8' }).trim()
    let ahead = 0, behind = 0
    try {
      const counts = execSync('git rev-list --left-right --count HEAD...@{upstream}', { cwd: path, encoding: 'utf8' }).trim().split('\t')
      ahead = parseInt(counts[0]) || 0
      behind = parseInt(counts[1]) || 0
    } catch {}
    const statusOutput = execSync('git status --porcelain', { cwd: path, encoding: 'utf8' })
    const files = statusOutput.split('\n').filter(Boolean).map(line => ({
      status: line.slice(0, 2).trim(),
      path: line.slice(3)
    }))
    sendTo(ws, { type: 'git_status_result', status: { branch, ahead, behind, files } })
  } catch (e) {
    sendTo(ws, { type: 'error', message: e.message })
  }
}

function handleGitDiff(path, file, ws, sendTo) {
  try {
    const cmd = file ? `git diff HEAD -- '${file}'` : 'git diff HEAD'
    const diff = execSync(cmd, { cwd: path, encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 })
    sendTo(ws, { type: 'git_diff_result', path, diff })
  } catch (e) {
    sendTo(ws, { type: 'error', message: e.message })
  }
}

function handleGitCommit(path, message, files, ws, sendTo) {
  try {
    for (const f of files) execSync(`git add '${f}'`, { cwd: path })
    const output = execSync(`git commit -m '${message.replace(/'/g, "'\\''")}'`, { cwd: path, encoding: 'utf8' })
    sendTo(ws, { type: 'git_commit_result', success: true, message: output })
  } catch (e) {
    sendTo(ws, { type: 'git_commit_result', success: false, message: e.message })
  }
}

const DEFAULT_PROJECT = process.env.CLOUDE_PROJECT || `${process.env.HOME}/projects/cloude`

function handleGetMemories(workingDirectory, ws, sendTo) {
  const dir = workingDirectory || DEFAULT_PROJECT
  const sections = []
  for (const file of ['CLAUDE.local.md']) {
    const path = join(dir, file)
    try {
      const content = readFileSync(path, 'utf8')
      const parts = content.split(/^## /m)
      for (const part of parts.slice(1)) {
        const nlIdx = part.indexOf('\n')
        const title = part.slice(0, nlIdx).trim()
        const body = part.slice(nlIdx + 1).trim()
        sections.push({ title, content: body })
      }
    } catch {}
  }
  sendTo(ws, { type: 'memories', sections })
}

function handleSearchFiles(query, workingDirectory, ws, sendTo) {
  try {
    const output = execSync(`find '${workingDirectory}' -maxdepth 5 -name '*${query}*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -50`, { encoding: 'utf8' })
    const files = output.split('\n').filter(Boolean)
    sendTo(ws, { type: 'file_search_results', files, query })
  } catch {
    sendTo(ws, { type: 'file_search_results', files: [], query })
  }
}

function handleGetPlans(workingDirectory, ws, sendTo) {
  const dir = workingDirectory || DEFAULT_PROJECT
  const stages = {}
  const plansDir = join(dir, '.claude', 'plans')
  log(`Plans dir: ${plansDir} (exists: ${existsSync(plansDir)}, workingDirectory: ${workingDirectory})`)
  if (!existsSync(plansDir)) return sendTo(ws, { type: 'plans', stages: {} })

  const stageFolders = ['00_backlog', '10_next', '20_active', '30_testing', '40_done']
  const stageNames = ['backlog', 'next', 'active', 'testing', 'done']
  for (let i = 0; i < stageFolders.length; i++) {
    const stageDir = join(plansDir, stageFolders[i])
    if (!existsSync(stageDir)) { stages[stageNames[i]] = []; continue }
    const files = readdirSync(stageDir).filter(f => f.endsWith('.md'))
    stages[stageNames[i]] = files.map(f => {
      const content = readFileSync(join(stageDir, f), 'utf8')
      const rawTitle = content.match(/^#\s+(.+)/m)?.[1] || f.replace('.md', '')
      const iconMatch = rawTitle.match(/^(.+?)\s*\{([a-z0-9.]+)\}$/i)
      const title = iconMatch ? iconMatch[1].trim() : rawTitle
      const icon = iconMatch ? iconMatch[2] : null
      const lines = content.split('\n')
      const headingIdx = lines.findIndex(l => l.trim().startsWith('# '))
      const quoteLines = []
      for (let j = headingIdx + 1; j < lines.length; j++) {
        const t = lines[j].trim()
        if ((t === '' || (t.startsWith('<!--') && t.endsWith('-->'))) && quoteLines.length === 0) continue
        if (t.startsWith('> ')) quoteLines.push(t.slice(2))
        else break
      }
      const description = quoteLines.slice(0, 3).join(' ').trim() || null
      let priority = null, tags = null, build = null
      for (const line of lines) {
        const t = line.trim()
        if (t.startsWith('<!--') && t.endsWith('-->')) {
          const inner = t.slice(4, -3).trim()
          const ci = inner.indexOf(':')
          if (ci === -1) continue
          const key = inner.slice(0, ci).trim()
          const val = inner.slice(ci + 1).trim()
          if (key === 'priority') priority = parseInt(val) || null
          if (key === 'tags') tags = val.split(',').map(s => s.trim())
          if (key === 'build') build = parseInt(val) || null
        }
      }
      return { filename: f, title, icon, description, priority, tags, build, content, path: join(stageDir, f) }
    })
  }
  sendTo(ws, { type: 'plans', stages })
}

const STAGE_TO_FOLDER = { backlog: '00_backlog', next: '10_next', active: '20_active', testing: '30_testing', done: '40_done' }

function handleDeletePlan(stage, filename, workingDirectory, ws, sendTo) {
  const dir = workingDirectory || DEFAULT_PROJECT
  const folder = STAGE_TO_FOLDER[stage] || stage
  const filePath = join(dir, '.claude', 'plans', folder, filename)
  try {
    unlinkSync(filePath)
    sendTo(ws, { type: 'plan_deleted', stage, filename })
  } catch (e) {
    sendTo(ws, { type: 'error', message: e.message })
  }
}

const WHISPER_PYTHON = join(import.meta.dirname, 'whisper-env', 'bin', 'python3')
const WHISPER_SCRIPT = join(import.meta.dirname, 'transcribe.py')

function handleTranscribe(audioBase64, ws, sendTo) {
  if (!audioBase64) {
    sendTo(ws, { type: 'error', message: 'No audio data provided' })
    return
  }

  log('Transcribing audio...')
  const proc = spawn(WHISPER_PYTHON, [WHISPER_SCRIPT])
  let stdout = ''
  let stderr = ''

  proc.stdout.on('data', d => { stdout += d })
  proc.stderr.on('data', d => { stderr += d })
  proc.stdin.write(audioBase64)
  proc.stdin.end()

  proc.on('close', code => {
    if (code !== 0) {
      log(`Transcription failed: ${stderr}`)
      sendTo(ws, { type: 'error', message: `Transcription failed: ${stderr.slice(0, 200)}` })
      return
    }
    try {
      const result = JSON.parse(stdout)
      log(`Transcribed: "${result.text?.slice(0, 50)}..."`)
      sendTo(ws, { type: 'transcription', text: result.text || '' })
    } catch (e) {
      sendTo(ws, { type: 'error', message: 'Failed to parse transcription result' })
    }
  })
}

function extractToolInput(name, input) {
  if (!input) return null
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
    default: return null
  }
}

function handleGetUsageStats(ws, sendTo) {
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

function handleListRemoteSessions(workingDirectory, ws, sendTo) {
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

function handleSyncHistory(sessionId, workingDirectory, ws, sendTo) {
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
            contentItem = { type: 'tool_use', toolName: item.name, toolId: item.id, toolInput: extractToolInput(item.name, item.input) }
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
          toolCalls.push({ name: item.toolName, input: item.toolInput || null, toolId: item.toolId, parentToolId: null, textPosition: text.length })
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

function handleTerminalExec(command, workingDirectory, ws, sendTo) {
  const cwd = workingDirectory ? workingDirectory.replace(/^~/, process.env.HOME) : process.env.HOME
  log(`Terminal exec: ${command} (cwd: ${cwd})`)

  const proc = spawn('bash', ['-c', command], { cwd, env: { ...process.env, TERM: 'xterm-256color', FORCE_COLOR: '1', CLICOLOR_FORCE: '1' } })
  let stdout = ''
  let stderr = ''

  proc.stdout.on('data', d => { stdout += d })
  proc.stderr.on('data', d => { stderr += d })

  proc.on('close', code => {
    const output = stdout + (stderr ? (stdout ? '\n' : '') + stderr : '')
    sendTo(ws, { type: 'terminal_output', output, exitCode: code, isError: code !== 0 })
  })

  proc.on('error', err => {
    sendTo(ws, { type: 'terminal_output', output: err.message, exitCode: 1, isError: true })
  })
}

const AVAILABLE_SYMBOLS = [
  "message", "message.fill", "bubble.left", "bubble.left.fill", "bubble.right", "bubble.right.fill", "phone", "phone.fill", "video", "video.fill", "envelope", "envelope.fill", "paperplane", "paperplane.fill", "bell", "bell.fill", "megaphone", "megaphone.fill",
  "sun.max", "sun.max.fill", "moon", "moon.fill", "moon.stars", "cloud", "cloud.fill", "cloud.bolt", "cloud.rain", "snowflake", "thermometer.sun",
  "pencil", "pencil.circle.fill", "folder", "folder.fill", "paperclip", "link", "book", "book.fill", "bookmark", "bookmark.fill", "tag", "tag.fill", "camera", "camera.fill", "photo", "photo.fill", "music.note", "headphones", "lightbulb", "lightbulb.fill", "cpu", "memorychip", "keyboard", "printer", "tv", "display",
  "iphone", "laptopcomputer", "desktopcomputer", "server.rack", "externaldrive", "gamecontroller", "gamecontroller.fill",
  "wifi", "antenna.radiowaves.left.and.right", "network", "globe", "globe.americas", "globe.europe.africa", "airplane", "car", "car.fill", "bicycle", "location", "location.fill", "map", "map.fill", "mappin",
  "leaf", "leaf.fill", "tree", "tree.fill", "mountain.2", "flame", "flame.fill", "drop", "drop.fill", "bolt", "bolt.fill", "sparkles", "star", "star.fill", "sun.horizon",
  "heart", "heart.fill", "heart.circle", "bolt.heart", "cross", "cross.fill", "pills", "brain.head.profile", "figure.walk", "figure.run", "dumbbell", "sportscourt",
  "cart", "cart.fill", "bag", "bag.fill", "creditcard", "creditcard.fill", "dollarsign.circle", "building.columns", "storefront", "basket", "barcode", "qrcode",
  "clock", "clock.fill", "alarm", "stopwatch", "timer", "hourglass", "calendar", "calendar.circle",
  "play", "play.fill", "play.circle", "pause", "pause.fill", "stop", "stop.fill", "shuffle", "repeat", "speaker", "speaker.wave.3", "music.mic", "guitars", "pianokeys", "theatermasks", "ticket",
  "trash", "trash.fill", "doc", "doc.fill", "doc.text", "clipboard", "clipboard.fill", "list.bullet", "list.number", "checklist",
  "arrow.up", "arrow.down", "arrow.clockwise", "arrow.counterclockwise", "arrow.triangle.2.circlepath", "arrow.up.arrow.down",
  "circle", "circle.fill", "square", "square.fill", "triangle", "triangle.fill", "diamond", "diamond.fill", "hexagon", "hexagon.fill", "shield", "shield.fill",
  "plus", "minus", "multiply", "number", "percent", "function", "chevron.left.forwardslash.chevron.right",
  "lock", "lock.fill", "key", "key.fill", "eye", "eye.fill", "eye.slash", "hand.raised", "hand.thumbsup", "exclamationmark.shield", "checkmark.shield",
  "terminal", "terminal.fill", "apple.terminal", "hammer", "hammer.fill", "wrench", "wrench.fill", "wrench.and.screwdriver", "gearshape", "gearshape.fill", "gearshape.2", "ant", "ant.fill", "ladybug",
  "checkmark", "checkmark.circle", "checkmark.circle.fill", "xmark", "xmark.circle", "exclamationmark.triangle", "info.circle", "questionmark.circle", "plus.circle", "minus.circle", "flag", "flag.fill", "bell.badge"
]

function handleSuggestName(text, context, conversationId, ws, sendTo) {
  if (!text || !conversationId) return

  let contextBlock = ''
  if (context && context.length) {
    contextBlock = '\nConversation so far:\n' + context.map(c => `- ${c.slice(0, 300)}`).join('\n') + '\n'
  }

  const symbolList = AVAILABLE_SYMBOLS.join(', ')
  const prompt = `You are naming a chat window in a mobile app. The user needs to glance at the name and instantly know what this conversation is about.
${contextBlock}
Latest user message: "${text}"

Suggest a short conversation name (1-3 words) that describes what's being worked on or discussed. Be specific and descriptive, not generic or catchy. Good examples: "Auth Bug Fix", "Dark Mode", "Rename Logic", "Memory System". Bad examples: "Spark", "New Chat", "Quick Fix".

Also pick an SF Symbol icon from this list that best fits the topic:
${symbolList}

Respond with ONLY a JSON object like: {"name": "Short Name", "symbol": "star"}
You MUST pick a symbol from the list above. Pick something specific and creative, not generic.
Prefer outline versions of icons (e.g. "star" over "star.fill") unless only a .fill variant exists.`

  const escaped = prompt.replace(/'/g, "'\\''")
  const command = `claude --model sonnet -p '${escaped}' --max-turns 1 --output-format text`

  log(`Name suggestion request for ${conversationId.slice(0, 8)}`)

  const proc = spawn('bash', ['-c', command], { env: { ...process.env, NO_COLOR: '1' } })
  let stdout = ''
  let stderr = ''

  const timeout = setTimeout(() => {
    proc.kill('SIGTERM')
    log('Name suggestion timed out')
  }, 15000)

  proc.stdout.on('data', d => { stdout += d })
  proc.stderr.on('data', d => { stderr += d })

  proc.on('close', code => {
    clearTimeout(timeout)
    const output = stdout.trim()
    if (!output) return

    let jsonStr = output
    const start = jsonStr.indexOf('{')
    const end = jsonStr.lastIndexOf('}')
    if (start !== -1 && end !== -1) jsonStr = jsonStr.slice(start, end + 1)

    try {
      const result = JSON.parse(jsonStr)
      if (result.name) {
        log(`Name suggestion: "${result.name}" symbol=${result.symbol || 'nil'}`)
        sendTo(ws, { type: 'name_suggestion', name: result.name, symbol: result.symbol || null, conversationId })
      }
    } catch {
      log(`Name suggestion parse failed: ${output.slice(0, 100)}`)
    }
  })

  proc.on('error', err => {
    clearTimeout(timeout)
    log(`Name suggestion error: ${err.message}`)
  })
}
