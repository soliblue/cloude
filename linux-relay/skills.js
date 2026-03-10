import { readdirSync, readFileSync, statSync, existsSync } from 'fs'
import { join } from 'path'
import { log } from './log.js'

export function loadSkills(projectRoot) {
  if (!projectRoot) return []

  const skillsDir = join(projectRoot, '.claude', 'skills')
  if (!existsSync(skillsDir)) return []

  try {
    const entries = readdirSync(skillsDir)
    const skills = []

    for (const entry of entries) {
      const entryPath = join(skillsDir, entry)
      const st = statSync(entryPath)

      let skillFile
      if (st.isDirectory()) {
        skillFile = join(entryPath, 'SKILL.md')
      } else if (entry.endsWith('.md')) {
        skillFile = entryPath
      } else {
        continue
      }

      const skill = parseSkillFile(skillFile)
      if (skill && skill.user_invocable) skills.push(skill)
    }

    log(`Loaded ${skills.length} skills`)
    return skills
  } catch (e) {
    log(`Failed to read skills directory: ${e.message}`)
    return []
  }
}

function parseSkillFile(path) {
  let content
  try { content = readFileSync(path, 'utf8') } catch { return null }

  if (!content.startsWith('---')) return null
  const endIdx = content.indexOf('\n---\n', 3)
  if (endIdx === -1) return null

  const frontmatter = content.slice(4, endIdx)

  let name = null
  let description = null
  let userInvocable = true
  let icon = null
  let aliases = []
  let parameters = []

  let inParameters = false
  let currentParam = {}

  for (const line of frontmatter.split('\n')) {
    const trimmed = line.trim()
    if (!trimmed) continue

    if (trimmed === 'parameters:') {
      inParameters = true
      continue
    }

    if (inParameters) {
      if (line.startsWith('  - ')) {
        if (currentParam.name) {
          parameters.push({ name: currentParam.name, placeholder: currentParam.placeholder || '', required: currentParam.required !== 'false' })
          currentParam = {}
        }
        const rest = line.slice(4)
        const ci = rest.indexOf(':')
        if (ci !== -1) {
          currentParam[rest.slice(0, ci).trim()] = rest.slice(ci + 1).trim()
        }
      } else if (line.startsWith('    ')) {
        const ci = trimmed.indexOf(':')
        if (ci !== -1) {
          currentParam[trimmed.slice(0, ci).trim()] = trimmed.slice(ci + 1).trim()
        }
      } else if (!line.startsWith(' ')) {
        inParameters = false
        if (currentParam.name) {
          parameters.push({ name: currentParam.name, placeholder: currentParam.placeholder || '', required: currentParam.required !== 'false' })
          currentParam = {}
        }
      }
    }

    if (!inParameters) {
      const ci = line.indexOf(':')
      if (ci === -1) continue
      const key = line.slice(0, ci).trim()
      const value = line.slice(ci + 1).trim()

      switch (key) {
        case 'name': name = value; break
        case 'description': description = value; break
        case 'user-invocable': userInvocable = value === 'true'; break
        case 'icon': icon = value; break
        case 'aliases':
          aliases = value.replace(/[\[\]]/g, '').split(',').map(s => s.trim()).filter(Boolean)
          break
      }
    }
  }

  if (currentParam.name) {
    parameters.push({ name: currentParam.name, placeholder: currentParam.placeholder || '', required: currentParam.required !== 'false' })
  }

  if (!name || !description) return null
  return { name, description, user_invocable: userInvocable, icon: icon || null, aliases, parameters }
}
