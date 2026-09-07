import test from 'node:test'
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { mkdtempSync, writeFileSync, renameSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { status, diff, commit, log, mutate } from '../src/Handlers/GitHandler.js'

function repository(t) {
  const directory = mkdtempSync(join(tmpdir(), 'afto-git-'))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  execFileSync('git', ['init', '-q', directory])
  execFileSync('git', ['-C', directory, 'config', 'user.email', 'fixture@example.invalid'])
  execFileSync('git', ['-C', directory, 'config', 'user.name', 'Afto Fixture'])
  return directory
}

test('Git status preserves Unicode, quotes, tabs, newlines and arrow text in filenames', async (t) => {
  const directory = repository(t)
  const files = ['café.swift', 'a -> b.txt', 'quote".txt', 'with\ttab.txt', 'with\nnewline.txt']
  for (const file of files) { writeFileSync(join(directory, file), 'before\n') }
  execFileSync('git', ['-C', directory, 'add', '.'])
  execFileSync('git', ['-C', directory, 'commit', '-qm', 'Initial files'])
  for (const file of files) { writeFileSync(join(directory, file), 'after\nextra\n') }
  const response = await status({ query: { path: directory } })
  assert.equal(response.status, 200)
  const changes = JSON.parse(response.body).changes
  assert.deepEqual(changes.map((change) => change.path).sort(), files.sort())
  assert.ok(changes.every((change) => change.additions === 2 && change.deletions === 1))
  for (const file of files) {
    const result = await diff({ query: { path: directory, file } })
    assert.match(result.body.toString(), /\+after/)
  }
})

test('Git status handles staged renames and their statistics without parsing display quoting', async (t) => {
  const directory = repository(t)
  writeFileSync(join(directory, 'old.txt'), 'one\ntwo\nthree\nfour\nfive\n')
  execFileSync('git', ['-C', directory, 'add', '.'])
  execFileSync('git', ['-C', directory, 'commit', '-qm', 'Initial'])
  renameSync(join(directory, 'old.txt'), join(directory, 'new -> name.txt'))
  writeFileSync(join(directory, 'new -> name.txt'), 'one\ntwo\nthree\nfour\nfive\nsix\n')
  execFileSync('git', ['-C', directory, 'add', '-A'])
  const changes = JSON.parse((await status({ query: { path: directory } })).body).changes
  assert.equal(changes.length, 1)
  assert.equal(changes[0].path, 'new -> name.txt')
  assert.equal(changes[0].type, 'renamed')
  assert.equal(changes[0].isStaged, true)
  assert.equal(changes[0].additions, 1)
})

test('Git history bounds pagination and rejects option-shaped commit IDs', async (t) => {
  const directory = repository(t)
  writeFileSync(join(directory, 'README.md'), 'fixture\n')
  execFileSync('git', ['-C', directory, 'add', '.'])
  execFileSync('git', ['-C', directory, 'commit', '-qm', 'Fixture history'])
  const response = await log({ query: { path: directory, skip: '-100', count: '-5' } })
  assert.equal(JSON.parse(response.body).commits.length, 1)
  assert.equal((await commit({ query: { path: directory, sha: '--output=/tmp/unwanted' } })).status, 400)
  const sha = execFileSync('git', ['-C', directory, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim()
  assert.equal((await commit({ query: { path: directory, sha } })).status, 200)
})

test('New files have a real addition diff before staging', async (t) => {
  const directory = repository(t)
  writeFileSync(join(directory, 'new file.txt'), 'first line\nsecond line\n')
  const response = await diff({ query: { path: directory, file: 'new file.txt' } })
  assert.equal(response.status, 200)
  assert.match(response.body.toString(), /\+first line/)
  assert.match(response.body.toString(), /\+second line/)
})

test('Git stage and unstage operate literally and preserve working files before the first commit', async (t) => {
  const directory = repository(t)
  writeFileSync(join(directory, '[draft].txt'), 'keep me\n')
  writeFileSync(join(directory, 'd.txt'), 'leave unstaged\n')
  const request = (action, files) => ({ body: Buffer.from(JSON.stringify({ path: directory, action, files })) })
  assert.equal((await mutate(request('stage', ['[draft].txt']))).status, 200)
  const staged = JSON.parse((await status({ query: { path: directory } })).body).changes.filter((change) => change.isStaged)
  assert.deepEqual(staged.map((change) => change.path), ['[draft].txt'])
  assert.equal((await mutate(request('unstage', ['[draft].txt']))).status, 200)
  assert.equal(JSON.parse((await status({ query: { path: directory } })).body).changes.filter((change) => change.isStaged).length, 0)
  assert.equal((await mutate(request('stage', ['../outside']))).status, 400)
  assert.equal((await mutate(request('stage', ['/etc/passwd']))).status, 400)
})

test('Git commit includes only staged files and rejects empty messages', async (t) => {
  const directory = repository(t)
  writeFileSync(join(directory, 'included.txt'), 'included\n')
  writeFileSync(join(directory, 'excluded.txt'), 'excluded\n')
  const request = (body) => ({ body: Buffer.from(JSON.stringify({ path: directory, ...body })) })
  await mutate(request({ action: 'stage', files: ['included.txt'] }))
  assert.equal((await mutate(request({ action: 'commit', message: '   ', files: ['included.txt'] }))).status, 400)
  assert.equal((await mutate(request({ action: 'commit', message: 'Commit staged work' }))).status, 200)
  assert.equal(execFileSync('git', ['-C', directory, 'ls-tree', '--name-only', 'HEAD'], { encoding: 'utf8' }).trim(), 'included.txt')
})

test('Diff pathspecs are literal and commit file lists preserve tabs, Unicode and newlines', async (t) => {
  const directory = repository(t)
  const files = ['[draft].txt', 'd.txt', 'line\nbreak.txt', '日本語\tname.txt']
  for (const file of files) writeFileSync(join(directory, file), 'before\n')
  execFileSync('git', ['-C', directory, 'add', '.'])
  execFileSync('git', ['-C', directory, 'commit', '-qm', 'subject\twith tab'])
  const history = JSON.parse((await log({ query: { path: directory } })).body).commits
  assert.equal(history[0].sha.length, 40)
  assert.equal(history[0].subject, 'subject\twith tab')
  const detail = JSON.parse((await commit({ query: { path: directory, sha: history[0].sha } })).body)
  assert.deepEqual(detail.files.map(file => file.path).sort(), files.sort())
  writeFileSync(join(directory, '[draft].txt'), 'literal change\n')
  writeFileSync(join(directory, 'd.txt'), 'glob must not match\n')
  const response = await diff({ query: { path: directory, file: '[draft].txt' } })
  assert.match(response.body.toString(), /\+literal change/)
  assert.doesNotMatch(response.body.toString(), /glob must not match/)
})
