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
      sendTo(ws, { type: 'usage_stats', stats: { totalSessions: 0, totalMessages: 0, firstSessionDate: null, dailyActivity: [], modelUsage: {}, hourCounts: {}, longestSession: null } })
      break

    case 'set_heartbeat_interval':
    case 'get_heartbeat_config':
    case 'mark_heartbeat_read':
    case 'trigger_heartbeat':
      sendTo(ws, { type: 'heartbeat_config', intervalMinutes: null, unreadCount: 0 })
      break

    case 'sync_history':
    case 'list_remote_sessions':
    case 'request_missed_response':
    case 'request_suggestions':
    case 'suggest_name':
    case 'get_scheduled_tasks':
    case 'toggle_scheduled_task':
    case 'delete_scheduled_task':
    case 'transcribe':
      handleTranscribe(msg.audioBase64, ws, sendTo)
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
          modified: st.mtime.getTime() / 1000 - 978307200,
          mimeType: d.isDirectory() ? null : (MIME_TYPES[extname(d.name)] || 'application/octet-stream')
        }
      } catch {
        return { name: d.name, path: fullPath, isDirectory: d.isDirectory(), size: 0, modified: Date.now() / 1000 - 978307200, mimeType: null }
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
