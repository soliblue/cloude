import test, { after } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'

const state = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-updater-state-'))
process.env.CLOUDE_DATA = state
after(() => fs.rmSync(state, { recursive: true, force: true }))
const { releaseFiles, applyRelease, latestRelease, isIdle } = await import('../src/Updater/DaemonUpdater.js')

test('release validation rejects symlinks and wrong versions; updating preserves voice and durable data', async (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-update-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  const release = path.join(root, 'release')
  const install = path.join(root, 'installed')
  for (const directory of ['release/src', 'release/scripts', 'installed/src', 'installed/whisper-env', 'installed/state']) { fs.mkdirSync(path.join(root, directory), { recursive: true }) }
  fs.writeFileSync(path.join(release, 'src/Version.js'), "export const DAEMON_VERSION = '1.2.3'")
  fs.writeFileSync(path.join(release, 'index.js'), 'new-entry')
  fs.writeFileSync(path.join(release, 'package.json'), '{"type":"module"}')
  fs.writeFileSync(path.join(release, 'scripts/run-tunnel.sh'), '#!/bin/bash\n')
  fs.writeFileSync(path.join(install, 'src/Version.js'), 'old-version')
  fs.writeFileSync(path.join(install, 'src/obsolete.js'), 'obsolete')
  fs.writeFileSync(path.join(install, 'whisper-env/proof'), 'model')
  fs.writeFileSync(path.join(install, 'state/auth-token'), 'secret')
  fs.writeFileSync(path.join(install, 'state/history.jsonl'), 'history')
  const archive = execFileSync('tar', ['--format=ustar', '-czf', '-', '-C', root, 'release'], { env: { ...process.env, COPYFILE_DISABLE: '1' } })
  const files = releaseFiles(archive, '1.2.3')
  assert.throws(() => releaseFiles(archive, '1.2.4'), /mismatched version/)
  assert.equal(await applyRelease(install, files, () => false), false)
  assert.equal(fs.readFileSync(path.join(install, 'src/Version.js'), 'utf8'), 'old-version')
  assert.equal(await applyRelease(install, files, () => true), true)
  assert.equal(fs.readFileSync(path.join(install, 'src/Version.js'), 'utf8'), "export const DAEMON_VERSION = '1.2.3'")
  assert.equal(fs.existsSync(path.join(install, 'src/obsolete.js')), false)
  assert.equal(fs.readFileSync(path.join(install, 'whisper-env/proof'), 'utf8'), 'model')
  assert.equal(fs.readFileSync(path.join(install, 'state/auth-token'), 'utf8'), 'secret')
  assert.equal(fs.readFileSync(path.join(install, 'state/history.jsonl'), 'utf8'), 'history')
  assert.ok(!fs.readdirSync(install).some((name) => name.startsWith('.update-')))
  fs.symlinkSync('/tmp', path.join(release, 'src/unsafe'))
  const symlinkArchive = execFileSync('tar', ['--format=ustar', '-czf', '-', '-C', root, 'release'], { env: { ...process.env, COPYFILE_DISABLE: '1' } })
  assert.throws(() => releaseFiles(symlinkArchive, '1.2.3'), /unsupported paths/)
})

test('a failed code swap restores every replaced entry before restart', async (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-update-rollback-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  fs.mkdirSync(path.join(root, 'src'))
  fs.writeFileSync(path.join(root, 'src/Version.js'), 'old')
  fs.writeFileSync(path.join(root, 'index.js'), 'old-entry')
  const rename = fs.renameSync
  fs.renameSync = (from, to) => {
    if (from.includes('/new/index.js')) { throw new Error('disk failure fixture') }
    return rename(from, to)
  }
  let restarted = false
  try {
    assert.throws(() => applyRelease(root, new Map([['src/Version.js', Buffer.from('new')], ['index.js', Buffer.from('new-entry')]]), () => true, () => { restarted = true }), /disk failure fixture/)
  } finally { fs.renameSync = rename }
  assert.equal(restarted, false)
  assert.equal(fs.readFileSync(path.join(root, 'src/Version.js'), 'utf8'), 'old')
  assert.equal(fs.readFileSync(path.join(root, 'index.js'), 'utf8'), 'old-entry')
  assert.ok(!fs.readdirSync(root).some((name) => name.startsWith('.update-')))
})


test('updater recognizes published calendar versions and selects highest valid release independent of API ordering', () => {
  const releases = [
    {tag_name:'linux-daemon-v2026.07.04.1'},
    {tag_name:'linux-daemon-v1.2.3'},
    {tag_name:'linux-daemon-v2026.09.07.1'},
    {tag_name:'linux-daemon-v2026.09.07.3',draft:true},
    {tag_name:'linux-daemon-v2026.09.07.2',prerelease:true},
    {tag_name:'macos-daemon-v2026.09.08.1'},
    {tag_name:'linux-daemon-v2026.09.08.1.invalid'},
    {tag_name:'linux-daemon-v9999999.1.1'}
  ]
  assert.equal(latestRelease(releases).tag_name,'linux-daemon-v2026.09.07.1')
  assert.equal(latestRelease(releases.slice(0,1)).tag_name,'linux-daemon-v2026.07.04.1')
  assert.equal(latestRelease([]),undefined)
})


test('automatic code replacement waits for every daemon-owned operation and preflight', async (t) => {
  const { runnerManager } = await import('../src/RunnerManager.js')
  const { codexClient } = await import('../src/Codex/CodexClient.js')
  const { codexSessions } = await import('../src/Codex/CodexSessions.js')
  const { codexCompaction } = await import('../src/Codex/CodexCompaction.js')
  const { codexTerminal } = await import('../src/Codex/CodexTerminal.js')
  const { agentSchedules } = await import('../src/Codex/AgentSchedules.js')
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-update-busy-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  fs.writeFileSync(path.join(root, 'index.js'), 'preserved')
  const blockers = [
    [runnerManager.runners, { hasExited: false }],
    [codexTerminal.entries, { status: 'running' }],
    [codexTerminal.starts, {}],
    [codexCompaction.states, { state: { status: 'pending' } }],
    [agentSchedules.active, {}],
    [codexClient.pending, {}],
    [codexClient.activeTurns, 'helper-turn'],
    [codexClient.serverRequests, {}],
    [codexSessions.steering, Promise.resolve()]
  ]
  assert.equal(isIdle(), true)
  for (const [registry, entry] of blockers) {
    registry.set('updater-test', entry)
    try {
      assert.equal(isIdle(), false)
      assert.equal(await applyRelease(root, new Map([['index.js', Buffer.from('replacement')]])), false)
      assert.equal(fs.readFileSync(path.join(root, 'index.js'), 'utf8'), 'preserved')
    } finally { registry.delete('updater-test') }
  }
  codexSessions.mutations.add('updater-test')
  assert.equal(isIdle(), false)
  codexSessions.mutations.delete('updater-test')
  for (const status of ['starting', 'running', 'waiting']) {
    agentSchedules.store.state.runs.push({ runId: 'updater-test', status })
    assert.equal(isIdle(), false)
    agentSchedules.store.state.runs.pop()
  }
  codexTerminal.entries.set('finished', { status: 'exited' })
  codexTerminal.starts.set('finished', { terminalId: 'finished' })
  codexCompaction.states.set('finished', { state: { status: 'completed' } })
  agentSchedules.store.state.runs.push({ runId: 'finished', status: 'completed' })
  try {
    assert.equal(isIdle(), true)
    assert.equal(await applyRelease(root, new Map([['index.js', Buffer.from('replacement')]])), true)
  } finally {
    codexTerminal.entries.delete('finished')
    codexTerminal.starts.delete('finished')
    codexCompaction.states.delete('finished')
    agentSchedules.store.state.runs.pop()
  }
})


test('final idle check through restart never yields to a prepared request or background dispatch', async (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-update-atomic-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  fs.writeFileSync(path.join(root, 'index.js'), 'old')
  const order = []
  const admitted = Promise.resolve().then(() => {
    order.push('prepared')
    return { send: () => order.push('admitted') }
  }).then(response => response.send())
  const update = Promise.resolve().then(() => {
    assert.equal(applyRelease(root, new Map([['index.js', Buffer.from('new')]]), () => {
      order.push('idle')
      return true
    }, () => {
      assert.equal(fs.readFileSync(path.join(root, 'index.js'), 'utf8'), 'new')
      assert.ok(!fs.readdirSync(root).some(name => name.startsWith('.update-')))
      order.push('restart')
    }), true)
  })
  await Promise.all([admitted, update])
  assert.deepEqual(order, ['prepared', 'idle', 'restart', 'admitted'])
  assert.equal(applyRelease(root, new Map([['index.js', Buffer.from('unused')]]), () => false, () => assert.fail('busy update restarted')), false)
})
