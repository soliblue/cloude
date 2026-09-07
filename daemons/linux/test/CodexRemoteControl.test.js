import test, { after } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-remote-control-'))
process.env.CLOUDE_DATA = directory
after(() => fs.rmSync(directory, { recursive: true, force: true }))
const { abort } = await import('../src/Handlers/ChatHandler.js')
const { codexClient } = await import('../src/Codex/CodexClient.js')
const { codexSessions } = await import('../src/Codex/CodexSessions.js')
const original = codexClient.request
after(() => { codexClient.request = original })
function body(response) { return JSON.parse(response.body) }

test('imported helper interruption uses its verified live turn without starting or resuming a task', async () => {
  const calls = []
  codexSessions.write('imported-child', { provider: 'codex', threadId: 'child-thread' })
  codexClient.request = async (method, params) => {
    calls.push({method, params})
    return method === 'thread/read' ? { thread: { id: 'child-thread', status: {type:'active'}, turns: [{id:'old-review',status:'inProgress'},{id:'current-child-turn',status:'inProgress'}] } } : {}
  }
  const response = await abort({}, {id:'imported-child'})
  assert.equal(response.status,200)
  assert.deepEqual(body(response), {ok:true,aborted:true,threadId:'child-thread',turnId:'current-child-turn'})
  assert.deepEqual(calls,[{method:'thread/read',params:{threadId:'child-thread',includeTurns:true}},{method:'turn/interrupt',params:{threadId:'child-thread',turnId:'current-child-turn'}}])
})

test('unknown, inactive, foreign, and stale task snapshots never interrupt an inferred turn', async () => {
  const calls = []
  codexClient.request = async (method, params) => { calls.push({method,params}); return {} }
  assert.equal(body(await abort({}, {id:'not-imported'})).aborted,false)
  assert.equal(calls.length,0)
  for(const [thread,status,aborted] of [
    [{id:'child-thread',status:{type:'idle'},turns:[{id:'stale',status:'inProgress'}]},200,false],
    [{id:'foreign-thread',status:{type:'active'},turns:[{id:'turn',status:'inProgress'}]},409,undefined],
    [{id:'child-thread',status:{type:'active'},turns:[{id:'stale',status:'inProgress'},{id:'latest',status:'completed'}]},409,undefined],
    [{id:'child-thread',status:{type:'active'},turns:[]},409,undefined]
  ]) {
    codexClient.request = async (method,params) => { calls.push({method,params}); return {thread} }
    const response=await abort({}, {id:'imported-child'})
    assert.equal(response.status,status)
    assert.equal(body(response).aborted,aborted)
  }
  assert.ok(calls.every(call=>call.method==='thread/read'))
})

test('remote interruption failures remain retryable without false completion or secret exposure', async () => {
  codexClient.request=async()=>{throw new Error('Bearer secret-token')}
  const response=await abort({}, {id:'imported-child'})
  assert.equal(response.status,502)
  assert.match(body(response).error,/Refresh/)
  assert.doesNotMatch(body(response).error,/secret-token/)
  assert.equal(body(response).aborted,undefined)
})
