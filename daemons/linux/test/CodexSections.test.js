import test, { after } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-sections-test-'))
process.env.CLOUDE_DATA = directory
after(() => fs.rmSync(directory, { recursive: true, force: true }))
const { THREAD_SOURCE_KINDS } = await import('../src/Codex/CodexThreadSources.js')
const { sections, updateSection, deleteSection, moveSection, sectionThreads } = await import('../src/Handlers/CodexSectionHandler.js')
const { threads } = await import('../src/Handlers/CodexHandler.js')
const { codexClient } = await import('../src/Codex/CodexClient.js')
const { codexSessions } = await import('../src/Codex/CodexSessions.js')
const { handle } = await import('../src/Routing/Router.js')
const { daemonToken } = await import('../src/Routing/DaemonAuth.js')
const original = codexClient.request
const calls = []
codexClient.request = async (method, params) => {
  calls.push({ method, params })
  return method === 'threadSection/list' || method === 'thread/list' ? { data: [], nextCursor: 'cursor-2' } : method === 'threadSection/create' || method === 'threadSection/update' ? { section: { id: 'section-1', name: params.name, appearance: params.appearance } } : {}
}
after(() => { codexClient.request = original })
function request(method = 'GET', value = {}, query = {}) {
  return { method, query, body: Buffer.from(JSON.stringify(value)), json: () => value }
}
function body(response) { return JSON.parse(response.body) }

test('sections map native pagination, create and update while preserving omitted appearance', async () => {
  assert.equal(body(await sections(request('GET', {}, { cursor: 'opaque', limit: '100' }))).nextCursor, 'cursor-2')
  assert.deepEqual(calls.at(-1), { method: 'threadSection/list', params: { cursor: 'opaque', limit: 100 } })
  assert.equal(body(await sections(request('POST', { name: '  Work  ', appearance: { icon: 'folder', color: 'blue' } }))).section.name, 'Work')
  assert.equal(calls.at(-1).method, 'threadSection/create')
  await updateSection(request('POST', { name: 'Renamed' }), { id: 'section-1' })
  assert.deepEqual(calls.at(-1), { method: 'threadSection/update', params: { sectionId: 'section-1', name: 'Renamed' } })
  await updateSection(request('POST', { name: 'Renamed', appearance: null }), { id: 'section-1' })
  assert.equal(calls.at(-1).params.appearance, null)
  await deleteSection(request('DELETE'), { id: 'section-1' })
  assert.deepEqual(calls.at(-1), { method: 'threadSection/delete', params: { sectionId: 'section-1' } })
})

test('moves use native task mappings and nullable membership without inference or resume', async () => {
  codexSessions.write('local-session', { threadId: 'native-thread', provider: 'codex' })
  await moveSection(request('POST', { sectionId: 'section-1', beforeThreadId: 'other-native' }), { id: 'local-session' })
  assert.deepEqual(calls.at(-1), { method: 'thread/section/move', params: { threadId: 'native-thread', sectionId: 'section-1', beforeThreadId: 'other-native' } })
  await moveSection(request('POST', { sectionId: null }), { id: 'native-unimported' })
  assert.deepEqual(calls.at(-1), { method: 'thread/section/move', params: { threadId: 'native-unimported', sectionId: null } })
  assert.ok(calls.every(call => !['turn/start', 'thread/resume', 'account/rateLimits/read'].includes(call.method)))
})

test('custom section ordering and all/unsectioned thread filters preserve cursor semantics', async () => {
  await sectionThreads(request('GET', {}, { cursor: 'page2', limit: '2' }), { id: 'section-1' })
  assert.deepEqual(calls.at(-1), { method: 'thread/list', params: { sectionId: 'section-1', sourceKinds: THREAD_SOURCE_KINDS, sortKey: 'section_position', sortDirection: 'asc', useStateDbOnly: true, cursor: 'page2', limit: 2 } })
  await threads(request('GET', {}, { unsectioned: 'true' }))
  assert.equal(calls.at(-1).params.sectionId, null)
  assert.ok(calls.at(-1).params.sourceKinds.includes('subAgentThreadSpawn'))
  assert.equal(calls.at(-1).params.sortKey, 'updated_at')
  await threads(request('GET', {}, { sectionId: 'section-1', limit: '3' }))
  assert.equal(calls.at(-1).params.sectionId, 'section-1')
  assert.equal(calls.at(-1).params.sortKey, 'section_position')
  assert.equal(calls.at(-1).params.sortDirection, 'asc')
  await threads(request('GET'))
  assert.equal(Object.hasOwn(calls.at(-1).params, 'sectionId'), false)
  assert.equal(Object.hasOwn(calls.at(-1).params, 'sourceKinds'), false)
})

test('malformed section requests are rejected before any native operation', async () => {
  const before = calls.length
  for (const name of ['', ' ', 'a'.repeat(121), 42, null, 'bad\nname']) assert.equal((await sections(request('POST', { name }))).status, 400)
  for (const appearance of [[], 'red', { unknown: 'x' }, { color: 123 }, { icon: 'x'.repeat(129) }]) assert.equal((await sections(request('POST', { name: 'Valid', appearance }))).status, 400)
  for (const query of [{ limit: '0' }, { limit: '101' }, { limit: '1.5' }, { limit: '-1' }, { limit: '01' }, { cursor: 'x'.repeat(4097) }, { unknown: 'x' }]) assert.equal((await sections(request('GET', {}, query))).status, 400)
  for (const value of [{}, {sectionId:42}, {sectionId:'x', beforeThreadId:42}, {sectionId:null, extra:true}]) assert.equal((await moveSection(request('POST', value), {id:'thread'})).status, 400)
  assert.equal((await updateSection(request('POST', {name:'Work'}),{id:'x'.repeat(513)})).status,400)
  assert.equal((await deleteSection(request('DELETE',{deleteThreads:true}),{id:'section'})).status,400)
  for(const query of [{sectionId:'one',unsectioned:'true'},{unsectioned:'invalid'},{sectionId:''},{limit:'101'}]) assert.equal((await threads(request('GET',{},query))).status,400)
  assert.equal(calls.length,before)
})

test('uncertain create errors are surfaced safely without duplicate creation attempts', async () => {
  const fake = codexClient.request
  let attempts = 0
  codexClient.request = async () => { attempts += 1; throw new Error('creation response lost Bearer credential123 secret=private https://example.com/token') }
  const response = await sections(request('POST', { name:'Work' }))
  codexClient.request = fake
  assert.equal(response.status,502)
  assert.equal(attempts,1)
  assert.match(body(response).error,/threadSection\/create/)
  assert.doesNotMatch(body(response).error,/credential123|private|example.com/)
})

test('all section routes require authentication and dispatch only their allowed method', async () => {
  for(const [method,url,value] of [['GET','/codex/sections',{}],['POST','/codex/sections',{name:'Work'}],['POST','/codex/sections/section-1/update',{name:'Work'}],['DELETE','/codex/sections/section-1',{}],['GET','/codex/sections/section-1/threads',{}],['POST','/sessions/native-thread/section',{sectionId:null}]]) {
    const req = {...request(method,value),path:url,headers:{}}
    assert.equal((await handle(req)).status,401)
    req.headers.authorization=`Bearer ${daemonToken()}`
    assert.equal((await handle(req)).status,200)
  }
})


test('section membership remains visible for helpers that native default source filters hide', async () => {
  const fake=codexClient.request
  codexClient.request=async(method,params)=>({data:params.sourceKinds?.includes('subAgentThreadSpawn')?[{id:'moved-helper',section:{id:'section-1',name:'Work'}}]:[]})
  try {
    assert.equal(body(await sectionThreads(request('GET'),{id:'section-1'})).data[0].id,'moved-helper')
    assert.equal(body(await threads(request('GET',{}, {sectionId:'section-1'}))).data[0].id,'moved-helper')
    assert.equal(body(await threads(request('GET',{}, {unsectioned:'true'}))).data[0].id,'moved-helper')
  } finally {codexClient.request=fake}
})
