import test, { after } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-fork-retries-'))
process.env.CLOUDE_DATA = directory
after(() => fs.rmSync(directory, { recursive: true, force: true }))
const { fork } = await import('../src/Handlers/CodexHandler.js')
const { codexClient } = await import('../src/Codex/CodexClient.js')
const { codexSessions, default: CodexSessions } = await import('../src/Codex/CodexSessions.js')
const originalRequest = codexClient.request
const originalPersist = codexSessions.persist
const originalWrite = codexSessions.write
after(() => { codexClient.request = originalRequest; codexSessions.persist = originalPersist; codexSessions.write = originalWrite })
const completed = [{ id: 'done', status: 'completed', items: [{ id: 'answer', type: 'agentMessage', text: 'original context' }] }]
function request(target, cwd = '/project') { return { json: () => ({ newSessionId: target, path: cwd }) } }
function snapshot(id) { return { thread: { id, cwd: '/project', status: { type: 'idle' }, turns: completed } } }
function body(response) { return JSON.parse(response.body) }

test('lost success replays the exact saved fork after process restart without provider calls', async () => {
 let forks = 0
 codexSessions.write('source-alias', { threadId: 'native-source', provider: 'codex' })
 codexClient.request = async method => {
  if (method === 'thread/read') return snapshot('native-source')
  forks += 1
  const receipt = JSON.parse(fs.readFileSync(codexSessions.file('retry-target', 'fork.json'), 'utf8'))
  assert.equal(receipt.status, 'pending')
  assert.equal(fs.statSync(codexSessions.file('retry-target', 'fork.json')).mode & 0o777, 0o600)
  assert.equal(fs.statSync(codexSessions.directory).mode & 0o777, 0o700)
  return snapshot('native-fork')
 }
 const first = await fork(request('RETRY-TARGET'), { id: 'Source-Alias' })
 assert.equal(first.status, 200)
 const repeat = await fork(request('retry-target'), { id: 'source-alias' })
 assert.equal(repeat.status, 200)
 assert.deepEqual(body(repeat).thread, body(first).thread)
 assert.equal(forks, 1)
 const script = `import assert from 'node:assert/strict'; import {fork} from ${JSON.stringify(new URL('../src/Handlers/CodexHandler.js', import.meta.url).href)}; import {codexClient} from ${JSON.stringify(new URL('../src/Codex/CodexClient.js', import.meta.url).href)}; codexClient.request=async()=>assert.fail('Restart replay called provider');const result=await fork({json:()=>({newSessionId:'retry-target',path:'/project'})},{id:'source-alias'});assert.equal(result.status,200);process.stdout.write(result.body);`
 const restarted = JSON.parse(execFileSync(process.execPath, ['--input-type=module', '-e', script], { env: { ...process.env, CLOUDE_DATA: directory }, encoding: 'utf8' }))
 assert.deepEqual(restarted, body(repeat))
 for (const [source, cwd] of [['other-source', '/project'], ['source-alias', '/other']]) {
  const result = await fork(request('retry-target', cwd), { id: source })
  assert.equal(result.status, 409)
  assert.equal(body(result).code, 'fork_conflict')
 }
 assert.equal(forks, 1)
})

test('concurrent identical attempts return retryable pending and conflicting attempts never share work', async () => {
 let resolve
 let forks = 0
 codexClient.request = async method => {
  if (method === 'thread/read') return snapshot('concurrent-source')
  forks += 1
  return new Promise(complete => { resolve = complete })
 }
 const first = fork(request('concurrent-target'), { id: 'concurrent-source' })
 await Promise.resolve(); await Promise.resolve()
 const pending = await fork(request('CONCURRENT-TARGET'), { id: 'concurrent-source' })
 assert.equal(body(pending).code, 'fork_pending')
 assert.equal(body(pending).retriable, true)
 assert.equal(body(await fork(request('concurrent-target', '/changed'), { id: 'concurrent-source' })).code, 'fork_conflict')
 resolve(snapshot('concurrent-child'))
 assert.equal((await first).status, 200)
 assert.equal((await fork(request('concurrent-target'), { id: 'concurrent-source' })).status, 200)
 assert.equal(forks, 1)
})

test('ambiguous provider failure remains pending across restarts and never forks again', async () => {
 let forks = 0
 codexClient.request = async method => {
  if (method === 'thread/read') return snapshot('ambiguous-source')
  forks += 1
  throw new Error('connection lost after provider accepted request')
 }
 const result = await fork(request('ambiguous-target'), { id: 'ambiguous-source' })
 assert.equal(body(result).code, 'fork_outcome_unknown')
 assert.equal(body(result).retriable, false)
 const script = `import assert from 'node:assert/strict';import {fork} from ${JSON.stringify(new URL('../src/Handlers/CodexHandler.js', import.meta.url).href)};import {codexClient} from ${JSON.stringify(new URL('../src/Codex/CodexClient.js', import.meta.url).href)};codexClient.request=async()=>assert.fail('Ambiguous restart retried provider');const r=await fork({json:()=>({newSessionId:'ambiguous-target',path:'/project'})},{id:'ambiguous-source'});assert.equal(r.status,409);assert.equal(JSON.parse(r.body).code,'fork_outcome_unknown');`
 execFileSync(process.execPath, ['--input-type=module', '-e', script], { env: { ...process.env, CLOUDE_DATA: directory } })
 assert.equal(forks, 1)
})

test('completed receipt recovers a missing mapping after a failed mapping write', async () => {
 let forks = 0
 codexClient.request = async method => {
  if (method === 'thread/read') return snapshot('repair-source')
  forks += 1
  return snapshot('repair-child')
 }
 codexSessions.write = () => { throw new Error('mapping disk failure') }
 const failed = await fork(request('repair-target'), { id: 'repair-source' })
 codexSessions.write = originalWrite
 assert.equal(body(failed).code, 'fork_storage_error')
 assert.equal(codexSessions.read('repair-target'), null)
 assert.equal((await fork(request('repair-target'), { id: 'repair-source' })).status, 200)
 assert.equal(codexSessions.read('repair-target').threadId, 'repair-child')
 assert.equal(forks, 1)
})

test('intent storage failure prevents provider work; failed completion storage never permits a duplicate', async () => {
 let forks = 0
 codexClient.request = async method => {
  if (method === 'thread/read') return snapshot('storage-source')
  forks += 1
  return snapshot('storage-child')
 }
 codexSessions.persist = () => { throw new Error('intent disk failure') }
 const failed = await fork(request('storage-before'), { id: 'storage-source' })
 codexSessions.persist = originalPersist
 assert.equal(body(failed).code, 'fork_preflight_failed')
 assert.equal(forks, 0)
 assert.equal((await fork(request('storage-before'), { id: 'storage-source' })).status, 200)
 assert.equal(forks, 1)
 codexSessions.persist = function(file, value, exclusive) {
  if (value.status === 'completed') throw new Error('receipt disk failure')
  return originalPersist.call(this, file, value, exclusive)
 }
 const after = await fork(request('storage-after'), { id: 'storage-source' })
 codexSessions.persist = originalPersist
 assert.equal(body(after).code, 'fork_outcome_unknown')
 assert.equal((await fork(request('storage-after'), { id: 'storage-source' })).status, 409)
 assert.equal(forks, 2)
})

test('partial durable intent and corrupt receipts fail closed without reissuing a provider fork', async () => {
 let forks = 0
 codexClient.request = async method => {
  if (method === 'thread/read') return snapshot('partial-source')
  forks += 1
  return snapshot('partial-child')
 }
 const sync = fs.fsyncSync
 fs.fsyncSync = () => { throw new Error('fsync failure after intent write') }
 try {
  assert.equal((await fork(request('partial-target'), { id: 'partial-source' })).status, 502)
 } finally { fs.fsyncSync = sync }
 assert.equal(forks, 0)
 assert.equal(body(await fork(request('partial-target'), { id: 'partial-source' })).code, 'fork_outcome_unknown')
 assert.equal(forks, 0)
 fs.writeFileSync(codexSessions.file('corrupt-target', 'fork.json'), '{')
 assert.equal(body(await fork(request('corrupt-target'), { id: 'partial-source' })).code, 'fork_conflict')
 assert.equal(forks, 0)
})


test('first fork intent persists newly created directory entries before returning', () => {
 const store = new CodexSessions(path.join(directory, 'new-parent', 'new-codex'))
 const open = fs.openSync
 const sync = fs.fsyncSync
 const files = new Map()
 const synced = []
 fs.openSync = (file, ...args) => { const descriptor = open(file, ...args); files.set(descriptor, file); return descriptor }
 fs.fsyncSync = descriptor => { synced.push(files.get(descriptor)); return sync(descriptor) }
 try {
  store.persist(store.file('first', 'fork.json'), { fingerprint: 'test', status: 'pending' }, true)
 } finally { fs.openSync = open; fs.fsyncSync = sync }
 assert.deepEqual(synced, [store.file('first', 'fork.json'), store.directory, path.dirname(store.directory), directory])
})


test('an already prepared chat stream cannot enter a reserved fork target or replace an active Codex runner', async () => {
 const {start}=await import('../src/Handlers/ChatHandler.js')
 const {runnerManager}=await import('../src/RunnerManager.js')
 let calls=0
 codexClient.request=async()=>{calls+=1;throw new Error('No provider work allowed')}
 const prepared=start({body:Buffer.from(JSON.stringify({provider:'codex',prompt:'pending input',path:'/project'}))},{id:'late-target'})
 assert.equal(prepared.status,200)
 codexSessions.reserve('late-target')
 let output=''
 try {
  prepared.streamer({end(value){output=value}})
  assert.equal(runnerManager.runners.has('late-target'),false)
  assert.equal(codexSessions.read('late-target'),null)
  assert.equal(calls,0)
  assert.equal(output.trim().split('\n').map(JSON.parse).at(-1).type,'exit')
  assert.throws(()=>runnerManager.start({sessionId:'late-target',provider:'codex'}),/being updated/)
 } finally {codexSessions.release('late-target')}
 const first={hasExited:false,threadId:'busy-native',abort(){assert.fail('Existing runner interrupted')}}
 runnerManager.runners.set('busy-owner',first)
 codexSessions.write('busy-alias',{threadId:'busy-native',provider:'codex'})
 try {
  for(const sessionId of ['busy-owner','busy-alias']) {
   assert.equal(runnerManager.start({sessionId,provider:'codex',response:{end(value){output=value}}}),null)
  }
  assert.equal(runnerManager.runners.get('busy-owner'),first)
  assert.equal(runnerManager.runners.has('busy-alias'),false)
  assert.equal(calls,0)
 } finally {runnerManager.runners.delete('busy-owner')}
})


test('completed receipt corruption cannot return incomplete history or overwrite its mapping', async () => {
 codexClient.request=async method=>snapshot(method==='thread/read'?'corrupt-snapshot-source':'corrupt-snapshot-child')
 assert.equal((await fork(request('corrupt-snapshot-target'),{id:'corrupt-snapshot-source'})).status,200)
 const file=codexSessions.file('corrupt-snapshot-target','fork.json')
 const receipt=JSON.parse(fs.readFileSync(file,'utf8'))
 for(const turns of [[],[{id:'done',status:'inProgress'}],[{status:'completed'}]]) {
  fs.writeFileSync(file,JSON.stringify({...receipt,thread:{...receipt.thread,turns}}))
  const result=await fork(request('corrupt-snapshot-target'),{id:'corrupt-snapshot-source'})
  assert.equal(result.status,409)
  assert.equal(body(result).code,'fork_conflict')
  assert.equal(codexSessions.read('corrupt-snapshot-target').threadId,'corrupt-snapshot-child')
 }
})
