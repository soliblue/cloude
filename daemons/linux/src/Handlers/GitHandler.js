import { spawn } from 'node:child_process'
import path from 'node:path'
import { randomUUID } from 'node:crypto'
import { existsSync, mkdirSync, readFileSync, realpathSync, readdirSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
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
    const child = spawn('/usr/bin/env', ['git', ...argumentsList], { cwd, timeout: 30_000, killSignal: 'SIGKILL' })
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
    child.on('close', (code, signal) => {
      if (size > maxOutputBytes || signal) {
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
  const records = output.split('\0')
  for (let index = 0; index < records.length; index += 1) {
    const line = records[index]
    if (line.length >= 3) {
      const pathText = line.slice(3)
      if (line.slice(0, 2).includes('R') || line.slice(0, 2).includes('C')) { index += 1 }
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
  const stats = Object.create(null)
  const records = output.split('\0')
  for (let index = 0; index < records.length; index += 1) {
    const parts = records[index].split('\t')
    if (parts.length >= 3) {
      const file = parts.slice(2).join('\t') || records[index + 2]
      if (parts[2] === '') { index += 2 }
      stats[file] = /^\d+$/u.test(parts[0]) && /^\d+$/u.test(parts[1])
        ? [Number.parseInt(parts[0], 10), Number.parseInt(parts[1], 10)] : [null, null]
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
      runText(['status', '--porcelain=v1', '-z', '-uall', '-M'], cwd),
      runText(['diff', '--numstat', '-z', '-M'], cwd),
      runText(['diff', '--cached', '--numstat', '-z', '-M'], cwd)
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
    const argumentsList = ['--literal-pathspecs', 'diff', '--no-color', '--no-ext-diff']
    const full = request.query.full === '1' || request.query.full === 'true'
    if (request.query.staged === '1' || request.query.staged === 'true') {
      argumentsList.push('--cached')
    }
    argumentsList.push('-M', '--', request.query.file)
    let [output, code] = await runText(argumentsList, resolved(request.query.path))
    if (code === 0 && !output && !argumentsList.includes('--cached')) {
      const [untracked] = await runText(['--literal-pathspecs', 'ls-files', '--others', '--exclude-standard', '-z', '--', request.query.file], resolved(request.query.path))
      if (untracked.split('\0').includes(request.query.file)) {
        [output, code] = await runText(['diff', '--no-index', '--no-color', '--', '/dev/null', request.query.file], resolved(request.query.path))
        code = code === 1 ? 0 : code
      }
    }
    if (code !== 0) { return HTTPResponse.json(500, { error: 'diff_failed' }) }
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

export async function commit(request) {
  if (request.query.path && /^[a-f0-9]{4,40}$/iu.test(request.query.sha || '')) {
    const cwd = resolved(request.query.path)
    const sha = request.query.sha
    const [meta] = await runText(['show', '-s', '--format=%H%n%an%n%aI%n%s%n%b', sha], cwd)
    const [numstat] = await runText(['show', '--numstat', '-z', '--format=', '-M', sha], cwd)
    const [diffText, code] = await runText(['show', '--no-color', '--format=', '-M', sha], cwd)
    if (code !== 0) {
      return HTTPResponse.json(404, { error: 'not_found' })
    }
    const metaLines = meta.split('\n')
    const files = Object.entries(parseNumstat(numstat)).map(([file, [additions, deletions]]) => ({
      additions: additions ?? 0, deletions: deletions ?? 0, path: file
    }))
    return HTTPResponse.json(200, {
      sha: metaLines[0] || sha,
      author: metaLines[1] || '',
      date: metaLines[2] || '',
      subject: metaLines[3] || '',
      body: metaLines.slice(4).join('\n').trim(),
      files,
      diff: diffText
    })
  }
  return HTTPResponse.json(400, { error: 'missing_params' })
}

export async function log(request) {
  if (request.query.path) {
    const [output] = await runText(
      [
        'log',
        '-z', '--format=%H%x00%s%x00%an%x00%aI',
        `--skip=${Math.max(0, Number.parseInt(request.query.skip || '0', 10) || 0)}`,
        `--max-count=${Math.min(200, Math.max(1, Number.parseInt(request.query.count || '50', 10) || 50))}`
      ],
      resolved(request.query.path)
    )
    return HTTPResponse.json(200, {
      commits: output.split('\0').reduce((commits, value, index, fields) => {
        if (index % 4 === 0 && value && fields[index + 3]) {
          commits.push({ sha: value, subject: fields[index + 1], author: fields[index + 2], date: fields[index + 3] })
        }
        return commits
      }, [])
    })
  }
  return HTTPResponse.json(400, { error: 'missing_path' })
}

export async function mutate(request) {
  const body = JSON.parse(request.body.toString('utf8'))
  if (typeof body.path === 'string' && ['stage', 'unstage', 'commit'].includes(body.action)) {
    const cwd = resolved(body.path)
    const [inside, insideCode] = await runText(['rev-parse', '--is-inside-work-tree'], cwd)
    if (insideCode === 0 && inside.trim() === 'true') {
      if (body.action === 'commit' && typeof body.message === 'string' && body.message.trim()) {
        const [output, code] = await runText(['commit', '-m', body.message.trim()], cwd)
        return HTTPResponse.json(code === 0 ? 200 : 409, code === 0 ? { ok: true, output } : { error: 'Commit failed. Check staged changes, Git identity, and hooks on your host.' })
      }
      if (['stage', 'unstage'].includes(body.action) && Array.isArray(body.files) && body.files.length > 0 && body.files.length <= 1000
        && body.files.every((file) => typeof file === 'string' && file.length > 0 && !path.isAbsolute(file) && !file.split('/').includes('..') && !file.includes('\0'))) {
        const [, headCode] = await runText(['rev-parse', '--verify', 'HEAD'], cwd)
        const argumentsList = body.action === 'stage' ? ['--literal-pathspecs', 'add', '--', ...body.files]
          : headCode === 0 ? ['--literal-pathspecs', 'restore', '--staged', '--', ...body.files]
            : ['--literal-pathspecs', 'rm', '--cached', '--', ...body.files]
        const [, code] = await runText(argumentsList, cwd)
        return HTTPResponse.json(code === 0 ? 200 : 409, code === 0 ? { ok: true } : { error: 'Could not update the Git index. Refresh and try again.' })
      }
    }
  }
  return HTTPResponse.json(400, { error: 'Invalid Git operation' })
}


const worktreeRequests = new Map()

async function readWorktrees(cwd) {
  const [output, code] = await runText(['worktree', 'list', '--porcelain', '-z'], cwd)
  return [output.split('\0\0').filter(Boolean).map((record, index) => {
    const fields = Object.fromEntries(record.split('\0').filter(Boolean).map((field) => {
      const separator = field.indexOf(' ')
      return separator === -1 ? [field, true] : [field.slice(0, separator), field.slice(separator + 1)]
    }))
    return { path: fields.worktree, branch: typeof fields.branch === 'string' ? fields.branch.replace(/^refs\/heads\//u, '') : null, head: fields.HEAD || '', isMain: index === 0, locked: 'locked' in fields, prunable: 'prunable' in fields }
  }), code]
}

export async function worktrees(request) {
  if (typeof request.query.path === 'string' && request.query.path && !request.query.path.includes('\0')) {
    const [entries, code] = await readWorktrees(resolved(request.query.path))
    return HTTPResponse.json(code === 0 ? 200 : 400, code === 0 ? { worktrees: entries } : { error: 'Choose an existing Git repository.' })
  }
  return HTTPResponse.json(400, { error: 'A repository path is required.' })
}

export async function branches(request) {
  if (typeof request.query.path === 'string' && request.query.path && !request.query.path.includes('\0')) {
    const cwd = resolved(request.query.path)
    const [[output, code], [remote], [current], [configured]] = await Promise.all([
      runText(['for-each-ref', '--format=%(refname:strip=2)%00%(HEAD)', 'refs/heads/'], cwd),
      runText(['symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD'], cwd),
      runText(['symbolic-ref', '--quiet', '--short', 'HEAD'], cwd),
      runText(['config', '--get', 'init.defaultBranch'], cwd)
    ])
    return HTTPResponse.json(code === 0 ? 200 : 400, code === 0 ? {
      branches: output.trim().split('\n').filter(Boolean).map((line) => ({ name: line.split('\0')[0], current: line.split('\0')[1] === '*' })),
      defaultBranch: remote.trim().replace(/^origin\//u, '') || current.trim() || configured.trim() || 'main'
    } : { error: 'Choose an existing Git repository.' })
  }
  return HTTPResponse.json(400, { error: 'A repository path is required.' })
}

export async function createWorktree(request) {
  const body = request.json()
  if (!(typeof body.path === 'string' && body.path && !body.path.includes('\0') && typeof body.branch === 'string' && body.branch.length <= 255 && !body.branch.startsWith('-') && !body.branch.includes('\0')
    && (body.baseRef === undefined || typeof body.baseRef === 'string' && body.baseRef.length > 0 && body.baseRef.length <= 255 && !body.baseRef.startsWith('-') && !body.baseRef.includes('\0'))
    && (body.requestId === undefined || typeof body.requestId === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/iu.test(body.requestId)))) {
    return HTTPResponse.json(400, { error: 'Provide a repository path, valid new branch name, optional base ref, and optional UUID requestId.' })
  }
  const id = (body.requestId || randomUUID()).toLowerCase()
  const previous = worktreeRequests.get(id) || Promise.resolve()
  const operation = previous.then(async () => {
    const cwd = resolved(body.path)
    const baseRef = body.baseRef || 'HEAD'
    const [[, branchCode], [common, commonCode], [, baseCode]] = await Promise.all([
      runText(['check-ref-format', `refs/heads/${body.branch}`], cwd),
      runText(['rev-parse', '--path-format=absolute', '--git-common-dir'], cwd),
      baseRef === 'HEAD' || /^[a-f0-9]{4,64}$/iu.test(baseRef) ? Promise.resolve(['', 0]) : runText(['check-ref-format', baseRef.startsWith('refs/') ? baseRef : `refs/heads/${baseRef}`], cwd)
    ])
    if (branchCode !== 0 || baseCode !== 0 || commonCode !== 0) { return HTTPResponse.json(400, { error: 'Choose an existing Git repository and valid branch and base ref names.' }) }
    const source = realpathSync(common.trim())
    const root = path.join(process.env.CLOUDE_DATA || path.join(homedir(), '.cloude-agent'), 'worktrees')
    mkdirSync(root, { recursive: true, mode: 0o700 })
    const target = path.join(realpathSync(root), id)
    const metadataPath = `${target}.json`
    let metadata
    if (existsSync(metadataPath)) {
      metadata = JSON.parse(readFileSync(metadataPath, 'utf8'))
      if (metadata.source !== source || metadata.branch !== body.branch || metadata.baseRef !== baseRef || !/^[a-f0-9]{40,64}$/iu.test(metadata.head || '')) {
        return HTTPResponse.json(409, { error: 'This request ID belongs to a different worktree request. Use a new request ID.' })
      }
      const [entries, code] = await readWorktrees(cwd)
      const existing = entries.find((entry) => entry.path === target)
      if (code === 0 && existing?.branch === body.branch && !existing.prunable) {
        return HTTPResponse.json(200, { path: target, branch: existing.branch, head: existing.head })
      }
      if (code !== 0 || existing) { return HTTPResponse.json(409, { error: 'The requested worktree has changed or is unavailable. Refresh worktrees on your host.' }) }
    }
    const [, existingCode] = await runText(['show-ref', '--verify', '--quiet', `refs/heads/${body.branch}`], cwd)
    if (existingCode === 0) { return HTTPResponse.json(409, { error: 'That branch already exists. Choose a new branch name.' }) }
    if (!metadata) {
      if (existsSync(target)) { return HTTPResponse.json(409, { error: 'This worktree directory is already reserved. Use a new request ID.' }) }
      const [head, headCode] = await runText(['rev-parse', '--verify', '--end-of-options', `${baseRef}^{commit}`], cwd)
      if (headCode !== 0) { return HTTPResponse.json(400, { error: 'The base ref must resolve to an existing commit. Commit the repository first or choose another base.' }) }
      metadata = { source, branch: body.branch, baseRef, head: head.trim() }
      writeFileSync(metadataPath, JSON.stringify(metadata), { mode: 0o600, flag: 'wx' })
      mkdirSync(target, { mode: 0o700 })
    } else if (!existsSync(target)) {
      mkdirSync(target, { mode: 0o700 })
    }
    if (realpathSync(target) !== target || readdirSync(target).length) { return HTTPResponse.json(409, { error: 'The reserved worktree directory is no longer empty. Refresh worktrees on your host.' }) }
    const [, code] = await runText(['-c', 'core.hooksPath=/dev/null', 'worktree', 'add', '-b', body.branch, '--', target, metadata.head], cwd)
    if (code !== 0) { return HTTPResponse.json(409, { error: 'Could not create the worktree. The branch may already exist or Git may be locked. Refresh and retry.' }) }
    return HTTPResponse.json(200, { path: target, branch: body.branch, head: metadata.head })
  })
  worktreeRequests.set(id, operation.then(() => {}, () => {}))
  const completion = worktreeRequests.get(id)
  void completion.then(() => { if (worktreeRequests.get(id) === completion) { worktreeRequests.delete(id) } })
  return operation
}
