import test, { after } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'afto-lifecycle-test-'))
process.env.CLOUDE_DATA=directory
after(()=>fs.rmSync(directory,{recursive:true,force:true}))
const {archive,fork,importThread,rename}=await import('../src/Handlers/CodexHandler.js')
const {start}=await import('../src/Handlers/ChatHandler.js')
const {codexClient}=await import('../src/Codex/CodexClient.js')
const {codexSessions}=await import('../src/Codex/CodexSessions.js')
const {runnerManager}=await import('../src/RunnerManager.js')
const original=codexClient.request
after(()=>{codexClient.request=original})
function request(value) {return {json:()=>value,body:Buffer.from(JSON.stringify(value))}}

test('archive flags and renamed task names reject malformed inputs without mutating a task', async()=>{
 let calls=0
 codexClient.request=async()=>{calls+=1;return {}}
 for(const value of [{archived:'false'},{archived:null},{archived:0},{archived:false,extra:true}]) assert.equal((await archive(request(value),{id:'thread'})).status,400)
 for(const value of [{name:'a\nline'},{name:'valid',extra:true},{name:'\u0000bad'}]) assert.equal((await rename(request(value),{id:'thread'})).status,400)
 assert.equal(calls,0)
})

test('active remote tasks cannot be archived and first-turn forks wait for completed history',async()=>{
 const calls=[]
 codexSessions.write('alias',{threadId:'native',provider:'codex'})
 codexClient.request=async(method,params)=>{calls.push({method,params});return {thread:{id:'native',status:{type:'active'},cwd:directory,turns:[{id:'first',status:'inProgress'}]}}}
 assert.equal((await archive(request({archived:true}),{id:'alias'})).status,409)
 assert.equal((await fork(request({newSessionId:'fork-active'}),{id:'alias'})).status,409)
 assert.ok(calls.every(call=>call.method==='thread/read'))
 assert.equal(codexSessions.busy('alias'),false)
 assert.equal(codexSessions.busy('fork-active'),false)
})

test('concurrent imports reserve their target against chat and cannot overwrite another import',async()=>{
 let complete
 codexClient.request=()=>new Promise(resolve=>{complete=resolve})
 const first=importThread(request({threadId:'first-native'}),{id:'Target'})
 await Promise.resolve()
 assert.equal((await importThread(request({threadId:'second-native'}),{id:'target'})).status,409)
 assert.equal(start(request({provider:'codex',path:directory,prompt:'must wait'}),{id:'TARGET'}).status,409)
 complete({thread:{id:'first-native',cwd:directory,status:{type:'active'}}})
 assert.equal((await first).status,200)
 assert.equal(codexSessions.read('target').threadId,'first-native')
 assert.equal(codexSessions.busy('target'),false)
})

test('concurrent forks cannot overwrite a target mapping and failures release reservations',async()=>{
 let complete
 const calls=[]
 codexClient.request=async(method,params)=>{
  calls.push({method,params})
  if(method==='thread/read')return {thread:{id:'source',status:{type:'idle'},cwd:directory,turns:[{id:'completed-turn',status:'completed'}]}}
  return new Promise(resolve=>{complete=resolve})
 }
 const first=fork(request({newSessionId:'Fork-Target'}),{id:'source'})
 await Promise.resolve();await Promise.resolve()
 assert.equal((await fork(request({newSessionId:'fork-target'}),{id:'source'})).status,409)
 complete({thread:{id:'first-fork',cwd:directory,turns:[{id:'completed-turn',status:'completed'}]}})
 assert.equal((await first).status,200)
 assert.equal(codexSessions.read('FORK-TARGET').threadId,'first-fork')
 assert.equal(calls.filter(call=>call.method==='thread/fork').length,1)
 codexClient.request=async()=>{throw new Error('native failure')}
 assert.equal((await importThread(request({threadId:'native'}),{id:'retry-target'})).status,502)
 assert.equal(codexSessions.busy('retry-target'),false)
})

test('invalid native identities preserve saved mappings and invalid fork IDs return 400',async()=>{
 codexSessions.write('preserved',{threadId:'saved',provider:'codex'})
 codexClient.request=async()=>({thread:{id:'wrong',cwd:directory}})
 assert.equal((await importThread(request({threadId:'requested'}),{id:'preserved'})).status,502)
 assert.equal(codexSessions.read('preserved').threadId,'saved')
 for(const newSessionId of [42,'','x'.repeat(513)]) assert.equal((await fork(request({newSessionId}),{id:'source'})).status,400)
})

test('case variants share one active runner for duplicate prevention, resume, and abort',async()=>{
 let aborted=0
 let subscribed=0
 runnerManager.runners.set('case-session',{threadId:'case-native',abort(){aborted+=1},subscribe(){subscribed+=1}})
 try {
  assert.equal(start(request({provider:'codex',path:directory,prompt:'duplicate'}),{id:'CASE-SESSION'}).status,409)
  assert.equal(runnerManager.abort('CASE-SESSION'),true)
  assert.equal(runnerManager.resumeIfExists('Case-Session',-1,{}),true)
  assert.equal(aborted,1)
  assert.equal(subscribed,1)
 } finally {runnerManager.runners.delete('case-session')}
})

test('steering validates IDs and replays accepted receipts after the original runner ends', async () => {
 const {steer}=await import('../src/Handlers/CodexHandler.js')
 const requestId='99999999-9999-4999-8999-999999999999'
 for(const value of [{prompt:''},{prompt:'x'.repeat(32769)},{prompt:'hi',requestId:'../bad'},{prompt:'hi',requestId:44}]) assert.equal((await steer(request(value),{id:'steer-session'})).status,400)
 await codexSessions.steer('steer-session',requestId,'hello',async()=>{})
 assert.equal((await steer(request({prompt:'hello',requestId}),{id:'STEER-SESSION'})).status,200)
 assert.equal((await steer(request({prompt:'changed',requestId}),{id:'steer-session'})).status,409)
 assert.equal((await steer(request({prompt:'hello',requestId}),{id:'different-session'})).status,409)
})


test('new chat cannot take over an imported active native task without a local runner', () => {
 codexSessions.write('remote-active-alias',{threadId:'remote-active-native',provider:'codex'})
 codexClient.activeTurns.set('remote-active-native','remote-existing-turn')
 try {
  assert.equal(start(request({provider:'codex',path:directory,prompt:'new message'}),{id:'remote-active-alias'}).status,409)
 } finally {codexClient.activeTurns.delete('remote-active-native')}
})


test('active forks pin a finished boundary and return only authoritative native history', async () => {
 const calls=[]
 const finished={id:'finished',status:'completed',items:[{type:'agentMessage',id:'answer',text:'native history'}]}
 codexSessions.write('fork-source-active',{threadId:'fork-source-native',provider:'codex'})
 runnerManager.runners.set('fork-source-active',{threadId:'fork-source-native'})
 codexClient.activeTurns.set('fork-source-native','unfinished')
 codexClient.request=async(method,params)=>{
  calls.push({method,params})
  if(method==='thread/read')return {thread:{id:'fork-source-native',cwd:directory,status:{type:'active'},turns:[finished,{id:'unfinished',status:'inProgress',items:[{type:'userMessage',id:'pending-user'}]}]}}
  return {thread:{id:'new-side-native',cwd:directory,status:{type:'idle'},turns:[finished]}}
 }
 try {
  const response=await fork(request({newSessionId:'safe-active-fork',path:directory}),{id:'fork-source-active'})
  assert.equal(response.status,200)
  assert.deepEqual(JSON.parse(response.body).thread.turns,[finished])
  assert.deepEqual(calls,[{method:'thread/read',params:{threadId:'fork-source-native',includeTurns:true}},{method:'thread/fork',params:{threadId:'fork-source-native',lastTurnId:'finished',deferGoalContinuation:true,excludeTurns:false,cwd:directory}}])
  assert.equal(codexClient.activeTurns.get('fork-source-native'),'unfinished')
  assert.equal(runnerManager.runners.has('fork-source-active'),true)
  assert.equal(codexSessions.read('safe-active-fork').threadId,'new-side-native')
 } finally {runnerManager.runners.delete('fork-source-active');codexClient.activeTurns.delete('fork-source-native')}
})

test('fork rejects missing finished boundary and invalid returned history without binding the target', async () => {
 for(const turns of [[],[{id:'first',status:'inProgress'}],[{id:'unknown',status:'unknown'}]]) {
  let calls=0
  codexClient.request=async()=>{calls+=1;return {thread:{id:'no-history',turns,cwd:directory}}}
  assert.equal((await fork(request({newSessionId:'no-boundary'}),{id:'no-history'})).status,409)
  assert.equal(calls,1)
  assert.equal(codexSessions.busy('no-boundary'),false)
 }
 codexClient.request=async(method)=>({thread:method==='thread/read'?{id:'bad-fork',cwd:directory,turns:[{id:'done',status:'interrupted'}]}:{id:'unsafe-fork',cwd:directory,turns:[{id:'unfinished',status:'inProgress'}]}})
 assert.equal((await fork(request({newSessionId:'unsafe-target'}),{id:'bad-fork'})).status,502)
 assert.equal(codexSessions.read('unsafe-target'),null)
 assert.equal(codexSessions.busy('unsafe-target'),false)
})

test('archive and restore retain native identity and restore precedes later history import', async () => {
 const calls=[]
 codexSessions.write('restored-alias',{threadId:'saved-archived',path:directory,provider:'codex'})
 codexClient.request=async(method,params)=>{calls.push({method,params});return {thread:{id:'saved-archived',cwd:directory,status:{type:'notLoaded'},turns:[]}}}
 assert.equal((await archive(request({archived:false}),{id:'restored-alias'})).status,200)
 assert.deepEqual(calls.map(call=>call.method),['thread/read','thread/unarchive'])
 assert.ok(calls.every(call=>call.params.threadId==='saved-archived'))
 assert.equal(codexSessions.read('restored-alias').threadId,'saved-archived')
 assert.equal((await importThread(request({threadId:'saved-archived'}),{id:'restore-new-alias'})).status,200)
 assert.equal(codexSessions.read('restore-new-alias').threadId,'saved-archived')
})


test('fork carries a saved goal without permitting initial automatic continuation', async () => {
 const calls=[]
 const goal={objective:'Keep investigating',status:'active'}
 codexClient.request=async(method,params)=>{
  calls.push({method,params})
  if(method==='thread/read')return {thread:{id:'goal-source',cwd:directory,turns:[{id:'done',status:'completed'}]}}
  assert.equal(params.deferGoalContinuation,true)
  assert.equal(params.excludeTurns,false)
  return {thread:{id:'goal-fork',cwd:directory,status:{type:'idle'},turns:[{id:'done',status:'completed'}],goal}}
 }
 const response=await fork(request({newSessionId:'goal-side-chat'}),{id:'goal-source'})
 assert.equal(response.status,200)
 assert.deepEqual(JSON.parse(response.body).thread.goal,goal)
 assert.deepEqual(calls.map(call=>call.method),['thread/read','thread/fork'])
})


test('fork rejects missing, reordered, substituted or extra finished history before saving the target', async () => {
 const finished=[{id:'first',status:'completed'},{id:'second',status:'interrupted'}]
 for(const returned of [[],[finished[1]],[finished[1],finished[0]],[finished[0],{id:'different',status:'completed'}],[...finished,{id:'later',status:'completed'}]]) {
  codexClient.request=async(method)=>({thread:{id:method==='thread/read'?'strict-source':'strict-child',cwd:directory,status:{type:'idle'},turns:method==='thread/read'?finished:returned}})
  assert.equal((await fork(request({newSessionId:'strict-target'}),{id:'strict-source'})).status,502)
  assert.equal(codexSessions.read('strict-target'),null)
  assert.equal(codexSessions.busy('strict-target'),false)
 }
 codexClient.request=async(method)=>({thread:{id:method==='thread/read'?'strict-source':'strict-child',cwd:directory,status:{type:method==='thread/read'?'idle':'active'},turns:finished}})
 assert.equal((await fork(request({newSessionId:'strict-target'}),{id:'strict-source'})).status,502)
 assert.equal(codexSessions.read('strict-target'),null)
 codexClient.request=async(method)=>({thread:{id:method==='thread/read'?'strict-source':'strict-child',cwd:directory,status:{type:'idle'},turns:finished}})
 const response=await fork(request({newSessionId:'strict-target'}),{id:'strict-source'})
 assert.equal(response.status,200)
 assert.deepEqual(JSON.parse(response.body).thread.turns,finished)
})
