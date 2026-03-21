import { readdirSync, readFileSync, existsSync, unlinkSync } from 'fs'
import { join } from 'path'
import { log } from './log.js'
import { resolveProject, sendError } from './shared.js'

export function handleGetMemories(workingDirectory, ws, sendTo) {
  const dir = resolveProject(workingDirectory)
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

export function handleGetPlans(workingDirectory, ws, sendTo) {
  const dir = resolveProject(workingDirectory)
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

export function handleDeletePlan(stage, filename, workingDirectory, ws, sendTo) {
  const dir = resolveProject(workingDirectory)
  const folder = STAGE_TO_FOLDER[stage] || stage
  const filePath = join(dir, '.claude', 'plans', folder, filename)
  try {
    unlinkSync(filePath)
    sendTo(ws, { type: 'plan_deleted', stage, filename })
  } catch (e) {
    sendError(ws, sendTo, e)
  }
}
