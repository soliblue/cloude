import { spawnSync } from 'node:child_process'
import path from 'node:path'
import HTTPResponse from '../Networking/HTTPResponse.js'

const diffClampLines = 5000

function resolved(filePath) {
  return filePath.startsWith('~/')
    ? path.join(process.env.HOME || '', filePath.slice(2))
    : filePath === '~'
      ? process.env.HOME || ''
      : path.resolve(filePath)
}

function runText(argumentsList, cwd) {
  const result = spawnSync('/usr/bin/env', ['git', ...argumentsList], {
    cwd,
    encoding: 'utf8',
    maxBuffer: 10 * 1024 * 1024
  })
  if (result.error) {
    return ['', -1]
  }
  return [result.stdout || '', typeof result.status === 'number' ? result.status : -1]
}

function resolveBranch(cwd) {
  const [branch] = runText(['branch', '--show-current'], cwd)
  if (branch.trim()) {
    return branch.trim()
  }
  const [sha] = runText(['rev-parse', '--short', 'HEAD'], cwd)
  return sha.trim()
}

function resolveAheadBehind(cwd) {
  const [upstream, upstreamCode] = runText(
    ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'],
    cwd
  )
  if (upstreamCode !== 0 || !upstream.trim()) {
    return [0, 0]
  }
  const [counts, countsCode] = runText(
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

export function status(request) {
  if (request.query.path) {
    const cwd = resolved(request.query.path)
    const [inside, insideCode] = runText(['rev-parse', '--is-inside-work-tree'], cwd)
    if (insideCode !== 0 || inside.trim() !== 'true') {
      return HTTPResponse.json(404, { error: 'not_a_repo' })
    }
    const [branch, [ahead, behind], porcelain, unstaged, staged] = [
      resolveBranch(cwd),
      resolveAheadBehind(cwd),
      runText(['status', '--porcelain=v1', '-uall', '-M'], cwd)[0],
      runText(['diff', '--numstat', '-M'], cwd)[0],
      runText(['diff', '--cached', '--numstat', '-M'], cwd)[0]
    ]
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

export function diff(request) {
  if (request.query.path && request.query.file) {
    const argumentsList = ['diff']
    const full = request.query.full === '1' || request.query.full === 'true'
    if (request.query.staged === '1' || request.query.staged === 'true') {
      argumentsList.push('--cached')
    }
    argumentsList.push('-M', '--', request.query.file)
    const output = runText(argumentsList, resolved(request.query.path))[0]
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

export function log(request) {
  if (request.query.path) {
    const output = runText(
      [
        'log',
        '--format=%h\t%s\t%an\t%aI',
        `--skip=${Number.parseInt(request.query.skip || '0', 10) || 0}`,
        `--max-count=${Number.parseInt(request.query.count || '50', 10) || 50}`
      ],
      resolved(request.query.path)
    )[0]
    return HTTPResponse.json(200, {
      commits: output
        .split('\n')
        .filter(Boolean)
        .map((line) => {
          const parts = line.split('\t')
          return {
            sha: parts[0],
            subject: parts[1],
            author: parts[2],
            date: parts[3]
          }
        })
    })
  }
  return HTTPResponse.json(400, { error: 'missing_path' })
}
