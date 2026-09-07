import assert from 'node:assert/strict'
import fs from 'node:fs'
import { randomUUID } from 'node:crypto'

const options = Object.fromEntries(Array.from({ length: (process.argv.length - 2) / 2 }, (_, index) => [process.argv[2 + index * 2].replace(/^--/u, ''), process.argv[3 + index * 2]]))
assert.ok(options.url && options['token-file'] && options.path && options.report, 'Required: --url --token-file --path --report; optional --model --skill-path --phase replay')
const headers = { Authorization: `Bearer ${fs.readFileSync(options['token-file'], 'utf8').trim()}`, 'Content-Type': 'application/json' }

async function api(route, body, method = body === undefined ? 'GET' : 'POST') {
  const response = await fetch(`${options.url}${route}`, { method, headers, ...(body === undefined ? {} : { body: JSON.stringify(body) }) })
  assert.ok(response.ok, `${method} ${route}: ${response.status}`)
  return response.json()
}

async function stream(response, callback = async () => true) {
  assert.equal(response.status, 200)
  const events = []
  const decoder = new TextDecoder()
  let buffer = ''
  for await (const chunk of response.body) {
    buffer += decoder.decode(chunk, { stream: true })
    let newline = buffer.indexOf('\n')
    while (newline !== -1) {
      const event = JSON.parse(buffer.slice(0, newline))
      events.push(event)
      buffer = buffer.slice(newline + 1)
      if (await callback(event) === false) { return events }
      newline = buffer.indexOf('\n')
    }
  }
  return events
}

async function turn(sessionId, prompt, extra = {}, callback) {
  const response = await fetch(`${options.url}/sessions/${sessionId}/chat`, { method: 'POST', headers, body: JSON.stringify({ path: options.path, provider: 'codex', model: options.model || 'gpt-5.6-luna', effort: 'low', prompt, ...extra }) })
  return stream(response, callback).catch(async (error) => { await api(`/sessions/${sessionId}/chat/abort`, {}); throw error })
}

function finalText(events) {
  assert.equal(events.at(-1)?.type, 'exit', 'Stream must terminate with an explicit exit')
  assert.equal(events.at(-1)?.code, 0, JSON.stringify(events.filter((event) => event.type === 'error')))
  return events.flatMap((event) => event.event?.type === 'assistant' ? event.event.message.content : []).filter((block) => block.type === 'text').map((block) => block.text).join('\n')
}

if (options.phase === 'replay') {
  const report = JSON.parse(fs.readFileSync(options.report, 'utf8'))
  const replay = await stream(await fetch(`${options.url}/sessions/${report.sessionId}/chat/resume?after_seq=0`, { headers }))
  assert.equal(replay[0].type, 'replay')
  assert.deepEqual(replay.slice(1), report.lastEvents)
  const continued = await turn(report.sessionId, 'What exact random identifier did I ask you to remember? Return only that identifier. Do not use tools.')
  assert.ok(finalText(continued).includes(report.proof), 'Restart must preserve native conversation context')
  assert.equal(continued.find((event) => event.type === 'session').threadId, report.threadId)
  await api(`/sessions/${report.sessionId}/archive`, { archived: true })
  console.log(JSON.stringify({ replayAfterRestart: true, continuedSameThreadAfterRestart: true, testThreadArchived: true }))
} else {
  assert.equal((await api('/codex/account')).account.type, 'chatgpt')
  assert.ok((await api('/codex/models')).data.some((model) => model.model === (options.model || 'gpt-5.6-luna')))
  const sessionId = randomUUID()
  const proof = randomUUID()
  const first = await turn(sessionId, `Remember this random identifier for later: ${proof}. Do not use tools. Reply only REMEMBERED.`)
  assert.ok(finalText(first).includes('REMEMBERED'))
  const threadId = first.find((event) => event.type === 'session').threadId
  const second = await turn(sessionId, 'What exact random identifier did I ask you to remember? Return only that identifier. Do not use tools.')
  assert.ok(finalText(second).includes(proof))
  assert.equal(second.find((event) => event.type === 'session').threadId, threadId)
  const forked = await api(`/sessions/${sessionId}/fork`, { newSessionId: randomUUID() })
  assert.notEqual(forked.threadId, threadId)
  assert.ok(finalText(await turn(forked.sessionId, 'What exact random identifier did I ask you to remember? Return only that identifier. Do not use tools.')).includes(proof))
  await api(`/sessions/${forked.sessionId}/archive`, { archived: true })
  const plan = await turn(sessionId, 'Plan a small text-only change to a file named draft.txt. Do not edit anything or use tools. Provide two concise planned steps.', { permissionMode: 'plan' })
  assert.ok(finalText(plan).length > 10)
  assert.ok(finalText(await turn(sessionId, 'Reply exactly DEFAULT_MODE_OK. Do not use tools.', { permissionMode: 'default' })).includes('DEFAULT_MODE_OK'))
  const manifest = await api(`/sessions/${sessionId}/manifest?provider=codex&path=${encodeURIComponent(options.path)}`)
  if (options['skill-path']) {
    assert.ok(manifest.skills.some((skill) => skill.path === options['skill-path']))
    assert.ok(finalText(await turn(sessionId, 'Follow the selected afto-proof skill exactly. Do not use tools.', { skills: [{ name: 'afto-proof', path: options['skill-path'] }] })).includes('SKILL_TRANSPORT_OK'))
  }
  let requested = 0
  const approval = await turn(sessionId, 'Use the command execution tool once to run exactly cat proof.txt in the current directory. Explicitly set sandbox_permissions to require_escalated and the justification to Verify mobile approval transport on a disposable test file. Do not run without requesting approval. Return the file contents.', {}, async (event) => {
    if (event.type === 'request') {
      const allowed = event.method === 'item/commandExecution/requestApproval' && event.params.cwd === options.path && ['cat proof.txt', "/bin/bash -lc 'cat proof.txt'", '/bin/bash -lc "cat proof.txt"'].includes(event.params.command)
      await api(`/sessions/${sessionId}/chat/respond`, { requestId: event.requestId, result: { decision: allowed ? 'accept' : 'decline' } })
      assert.ok(allowed, 'Unexpected approval was declined')
      requested += 1
    }
    return true
  })
  assert.ok(finalText(approval).includes('AFTO_REMOTE_LINUX_APPROVAL_OK'))
  assert.ok(requested > 0, 'The model must actually request approval for this check')
  const partial = await turn(sessionId, 'Write the integers 1 through 60, one per line. Do not use tools.', {}, async (event) => !(event.event?.event?.delta?.type === 'text_delta'))
  assert.notEqual(partial.at(-1).type, 'exit')
  const resumed = await stream(await fetch(`${options.url}/sessions/${sessionId}/chat/resume?after_seq=${partial.at(-1).seq}`, { headers }))
  assert.ok(finalText([...partial, ...resumed]).includes('60'))
  assert.equal(new Set([...partial, ...resumed].map((event) => event.seq)).size, partial.length + resumed.length)
  let interrupted = false
  const stopped = await turn(sessionId, 'Write the integers 1 through 10000. Do not use tools.', {}, async (event) => {
    if (!interrupted && event.codex?.method === 'turn/started') { interrupted = true; await api(`/sessions/${sessionId}/chat/abort`, {}) }
    return true
  })
  assert.ok(stopped.some((event) => event.type === 'aborted'))
  const lastEvents = await turn(sessionId, 'Reply exactly RESTART_REPLAY_READY. Do not use tools.')
  assert.ok(finalText(lastEvents).includes('RESTART_REPLAY_READY'))
  fs.writeFileSync(options.report, JSON.stringify({ sessionId, threadId, proof, lastEvents }), { mode: 0o600 })
  console.log(JSON.stringify({ sessionId, repeatTurn: true, forkContext: true, planAndDefault: true, nativeSkill: Boolean(options['skill-path']), approvalRoundtrip: requested, liveReconnect: true, interrupt: true, readyForRestartReplay: true }))
}
