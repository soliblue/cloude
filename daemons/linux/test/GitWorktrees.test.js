import test from 'node:test'
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { randomUUID } from 'node:crypto'
import { mkdtempSync, writeFileSync, readFileSync, rmSync, statSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { branches, worktrees, createWorktree } from '../src/Handlers/GitHandler.js'
import HTTPRequest from '../src/Networking/HTTPRequest.js'
import { handle as ping } from '../src/Handlers/PingHandler.js'

if (process.platform === 'darwin') { process.env.PATH = `/usr/bin:${process.env.PATH}` }

function git(directory, ...args) { return execFileSync('git', ['-C', directory, ...args], { encoding: 'utf8' }).trim() }
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'afto-worktrees-'))
  const repository = join(root, 'repository with\nnewline')
  process.env.CLOUDE_DATA = join(root, 'data')
  t.after(() => rmSync(root, { recursive: true, force: true }))
  execFileSync('git', ['init', '-q', '-b', 'main', repository])
  git(repository, 'config', 'user.name', 'Fixture')
  git(repository, 'config', 'user.email', 'fixture@example.invalid')
  writeFileSync(join(repository, 'proof.txt'), 'committed\n')
  git(repository, 'add', '.')
  git(repository, 'commit', '-qm', 'Initial')
  return repository
}
function create(path, body) { return createWorktree(new HTTPRequest('POST', '/', {}, {}, Buffer.from(JSON.stringify({ path, ...body })))) }
function body(response) { return JSON.parse(response.body) }

test('worktrees preserve dirty source and expose local branches, lock flags, detached HEAD and canonical paths', async (t) => {
  const source = fixture(t)
  writeFileSync(join(source, 'proof.txt'), 'staged\n')
  git(source, 'add', '.')
  writeFileSync(join(source, 'proof.txt'), 'unstaged\n')
  writeFileSync(join(source, 'untracked.txt'), 'untouched\n')
  const status = git(source, 'status', '--porcelain=v1', '-z')
  const index = readFileSync(join(source, '.git/index'))
  const requestId = randomUUID()
  const response = await create(source, { branch: 'codex/new-task', requestId, baseRef: 'main' })
  assert.equal(response.status, 200, response.body.toString())
  const result = body(response)
  assert.equal(readFileSync(join(result.path, 'proof.txt'), 'utf8'), 'committed\n')
  assert.equal(git(source, 'status', '--porcelain=v1', '-z'), status)
  assert.deepEqual(readFileSync(join(source, '.git/index')), index)
  assert.equal(git(source, 'branch', '--show-current'), 'main')
  assert.equal(statSync(`${result.path}.json`).mode & 0o777, 0o600)
  const catalog = body(await branches({ query: { path: source } }))
  assert.equal(catalog.defaultBranch, 'main')
  assert.deepEqual(catalog.branches, [{ name: 'codex/new-task', current: false }, { name: 'main', current: true }])
  git(source, 'worktree', 'lock', '--reason', 'fixture', result.path)
  let entries = body(await worktrees({ query: { path: source } })).worktrees
  assert.equal(entries[0].isMain, true)
  assert.ok(entries[0].path.endsWith('repository with\nnewline'))
  assert.equal(entries[1].locked, true)
  assert.equal(entries[1].prunable, false)
  git(result.path, 'checkout', '--detach', '-q')
  entries = body(await worktrees({ query: { path: source } })).worktrees
  assert.equal(entries[1].branch, null)
})

test('stable request IDs serialize duplicate creates and recover after handler reload without re-resolving moved base', async (t) => {
  const source = fixture(t)
  const request = { branch: 'retry-safe', requestId: randomUUID(), baseRef: 'main' }
  const responses = await Promise.all([create(source, request), create(source, request), create(source, request)])
  assert.ok(responses.every((response) => response.status === 200))
  assert.deepEqual(body(responses[0]), body(responses[2]))
  git(source, 'commit', '--allow-empty', '-qm', 'Main moved')
  const reloaded = await import(`../src/Handlers/GitHandler.js?restart=${randomUUID()}`)
  const replay = await reloaded.createWorktree(new HTTPRequest('POST', '/', {}, {}, Buffer.from(JSON.stringify({ path: source, ...request }))))
  assert.equal(replay.status, 200)
  assert.deepEqual(body(replay), body(responses[0]))
  assert.equal((await create(source, { ...request, branch: 'different' })).status, 409)
  assert.equal((await create(source, { ...request, baseRef: 'HEAD' })).status, 409)
  assert.equal(body(await worktrees({ query: { path: source } })).worktrees.length, 2)
})

test('concurrent unique creates succeed while colliding branches are rejected', async (t) => {
  const source = fixture(t)
  const unique = await Promise.all(['task-one', 'task-two'].map((branch) => create(source, { branch, requestId: randomUUID() })))
  assert.deepEqual(unique.map((response) => response.status), [200, 200])
  assert.notEqual(body(unique[0]).path, body(unique[1]).path)
  const collision = await Promise.all([create(source, { branch: 'same' }), create(source, { branch: 'same' })])
  assert.deepEqual(collision.map((response) => response.status).sort(), [200, 409])
  assert.equal((await create(source, { branch: 'main' })).status, 409)
})

test('invalid refs, revision expressions, nonexistent bases and invalid request IDs never create worktrees', async (t) => {
  const source = fixture(t)
  for (const branch of ['--force', '../escape', 'bad..ref', 'name with space', '@{-1}', '', 'nul\0byte']) {
    assert.equal((await create(source, { branch })).status, 400, branch)
  }
  for (const baseRef of ['--output=/tmp/x', 'HEAD~1', 'HEAD^', 'missing', 'main:proof.txt']) {
    assert.equal((await create(source, { branch: 'new', baseRef })).status, 400, baseRef)
  }
  assert.equal((await create(source, { branch: 'new', requestId: '../escape' })).status, 400)
  assert.equal(body(await worktrees({ query: { path: source } })).worktrees.length, 1)
})

test('capability headers and ping advertise matching implemented Git routes', () => {
  const response = ping()
  const headers = new Map()
  response.send({ setHeader: (key, value) => headers.set(key, value), end: () => {} })
  assert.deepEqual(body(response).capabilities, ['codex', 'gitMutations', 'gitWorktrees', 'codexPlugins', 'codexCompaction', 'codexReview', 'codexShell', 'codexSections', 'codexTerminal', 'agentSchedules'])
  assert.equal(headers.get('X-Daemon-Capabilities'), body(response).capabilities.join(','))
})
