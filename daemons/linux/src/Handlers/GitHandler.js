import { spawn } from 'node:child_process'
import path from 'node:path'
import HTTPResponse from '../Networking/HTTPResponse.js'

const diffClampLines = 5000
const maxOutputBytes = 10 * 1024 * 1024

function resolved(filePath) {
  return filePath.startsWith('~/')
    ? path.join(process.env.HOME || '', filePath.slice(2))
    : filePath === '~'
      ? process.env.HOME || ''
      : path.resolve(filePath)
}

function runText(argumentsList, cwd) {
  return new Promise((resolve) => {
    const child = spawn('/usr/bin/env', ['git', ...argumentsList], { cwd })
    const chunks = []
    let size = 0
    child.stdout.on('data', (chunk) => {
      size += chunk.length
      if (size > maxOutputBytes) {
        child.kill('SIGKILL')
        return
      }
      chunks.push(chunk)
    })
    child.stderr.resume()
    child.on('error', () => resolve(['', -1]))
    child.on('close', (code) => {
      if (size > maxOutputBytes) {
        resolve(['', -1])
      } else {
        resolve([Buffer.concat(chunks).toString('utf8'), typeof code === 'number' ? code : -1])
      }
    })
  })
}

async function resolveBranch(cwd) {
  const [branch] = await runText(['branch', '--show-current'], cwd)
  if (branch.trim()) {
    return branch.trim()
  }
  const [sha] = await runText(['rev-parse', '--short', 'HEAD'], cwd)
  return sha.trim()
}

async function resolveAheadBehind(cwd) {
  const [upstream, upstreamCode] = await runText(
    ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'],
    cwd
  )
  if (upstreamCode !== 0 || !upstream.trim()) {
    return [0, 0]
  }
  const [counts, countsCode] = await runText(
    ['rev-list', '--left-right', '--count', `${upstream.trim()}...HEAD`],
    cwd
  )
  if (countsCode !== 0) {
    return [0, 0]
  }
  const parts = counts.trim().split('\t')
  if (parts.length === 2) {
    return [Number.parseInt(parts[1], 10) || 0, Number.parseInt(parts[0], 10) || 0]
  }
  return [0, 0]
}

function typeFor(code) {
  if (code === 'A') {
    return 'added'
  }
  if (code === 'D') {
    return 'deleted'
  }
  if (code === 'R') {
    return 'renamed'
  }
  if (code === 'C') {
    return 'copied'
  }
  if (code === 'U') {
    return 'conflicted'
  }
  return 'modified'
}

function parsePorcelain(output) {
  const changes = []
  for (const line of output.split('\n')) {
    if (line.length >= 3) {
      const pathText = line.includes(' -> ') ? line.slice(line.indexOf(' -> ') + 4) : line.slice(3)
      if (line[0] === '?') {
        changes.push({ path: pathText, type: 'untracked', isStaged: false })
      } else {
        if (line[0] !== ' ' && line[0] !== '!') {
          changes.push({ path: pathText, type: typeFor(line[0]), isStaged: true })
        }
        if (line[1] !== ' ' && line[1] !== '!') {
          changes.push({ path: pathText, type: typeFor(line[1]), isStaged: false })
        }
      }
    }
  }
  return changes
}

function parseNumstat(output) {
  const stats = {}
  for (const line of output.split('\n')) {
    const parts = line.split('\t')
    if (parts.length >= 3 && /^\d+$/u.test(parts[0]) && /^\d+$/u.test(parts[1])) {
      const file = parts[2].includes(' => ') ? parts[2].slice(parts[2].indexOf(' => ') + 4) : parts[2]
      stats[file] = [Number.parseInt(parts[0], 10), Number.parseInt(parts[1], 10)]
    }
  }
  return stats
}

export async function status(request) {
  if (request.query.path) {
    const cwd = resolved(request.query.path)
    const [inside, insideCode] = await runText(['rev-parse', '--is-inside-work-tree'], cwd)
    if (insideCode !== 0 || inside.trim() !== 'true') {
      return HTTPResponse.json(404, { error: 'not_a_repo' })
    }
    const [branch, [ahead, behind], [porcelain], [unstaged], [staged]] = await Promise.all([
      resolveBranch(cwd),
      resolveAheadBehind(cwd),
      runText(['status', '--porcelain=v1', '-uall', '-M'], cwd),
      runText(['diff', '--numstat', '-M'], cwd),
      runText(['diff', '--cached', '--numstat', '-M'], cwd)
    ])
    const changes = parsePorcelain(porcelain)
    const unstagedStats = parseNumstat(unstaged)
    const stagedStats = parseNumstat(staged)
    for (const change of changes) {
      const stats = change.isStaged ? stagedStats : unstagedStats
      if (stats[change.path]) {
        change.additions = stats[change.path][0]
        change.deletions = stats[change.path][1]
      }
    }
    return HTTPResponse.json(200, { branch, ahead, behind, changes })
  }
  return HTTPResponse.json(400, { error: 'missing_path' })
}

export async function diff(request) {
  if (request.query.path && request.query.file) {
    const argumentsList = ['diff']
    const full = request.query.full === '1' || request.query.full === 'true'
    if (request.query.staged === '1' || request.query.staged === 'true') {
      argumentsList.push('--cached')
    }
    argumentsList.push('-M', '--', request.query.file)
    const [output] = await runText(argumentsList, resolved(request.query.path))
    const lines = output.split('\n')
    if (!full && lines.length > diffClampLines) {
      return new HTTPResponse(
        200,
        Buffer.from(lines.slice(0, diffClampLines).join('\n')),
        'text/plain; charset=utf-8',
        { 'X-Diff-Truncated': String(lines.length) }
      )
    }
    return HTTPResponse.text(200, output)
  }
  return HTTPResponse.json(400, { error: 'missing_params' })
}

export async function log(request) {
  if (request.query.path) {
    const [output] = await runText(
      [
        'log',
        '--format=%h\t%s\t%an\t%aI',
        `--skip=${Number.parseInt(request.query.skip || '0', 10) || 0}`,
        `--max-count=${Number.parseInt(request.query.count || '50', 10) || 50}`
      ],
      resolved(request.query.path)
    )
    return HTTPResponse.json(200, {
      commits: output
        .split('\n')
        .filter(Boolean)
        .map((line) => {
          const parts = line.split('\t')
          if (parts.length < 4) {
            return null
          }
          return {
            sha: parts[0],
            subject: parts.slice(1, parts.length - 2).join('\t'),
            author: parts[parts.length - 2],
            date: parts[parts.length - 1]
          }
        })
        .filter(Boolean)
    })
  }
  return HTTPResponse.json(400, { error: 'missing_path' })
}
