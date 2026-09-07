import test from 'node:test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { isTranscribing, transcribe } from '../src/Handlers/TranscribeHandler.js'

const request = (audio = Buffer.from('fixture audio').toString('base64')) => ({ body: Buffer.from(JSON.stringify({ audio })) })
const processOptions = (source, timeout = 5_000) => ({
  ready: () => true,
  timeout,
  createProcess: (_command, _args, options) => spawn(process.execPath, ['-e', source], options)
})

test('transcription validates input and unavailable local models before starting a process', async () => {
  assert.equal((await transcribe({ body: Buffer.from('{') })).status, 400)
  assert.equal((await transcribe(request(''))).status, 400)
  assert.equal((await transcribe(request('%%%'))).status, 400)
  assert.equal((await transcribe(request('YQ'))).status, 400)
  assert.equal((await transcribe(request('A'.repeat(16 * 1024 * 1024 + 1)))).status, 413)
  assert.equal((await transcribe(request(), { ready: () => false })).status, 503)
})

test('transcription passes exact audio to a local child and preserves Unicode and empty transcripts', async () => {
  const audio = Buffer.from([0, 255, 128, 10, 13]).toString('base64')
  const response = await transcribe(request(audio), processOptions(`
    let input = '';
    process.stdin.on('data', chunk => input += chunk);
    process.stdin.on('end', () => process.stdout.write(JSON.stringify({text: input + ' café 中文'})));
  `))
  assert.equal(response.status, 200)
  assert.equal(JSON.parse(response.body).text, audio + ' café 中文')
  const empty = await transcribe(request(), processOptions(`process.stdin.resume(); process.stdout.write('{"text":""}');`))
  assert.equal(empty.status, 200)
  assert.equal(JSON.parse(empty.body).text, '')
})

test('one CPU transcription runs at a time and a timed-out child frees the slot', async () => {
  const first = transcribe(request(), processOptions('process.stdin.resume(); setInterval(() => {}, 1000);', 120))
  assert.equal(isTranscribing(), true)
  assert.equal((await transcribe({ get body() { assert.fail('busy request parsed body') } })).status, 429)
  const canceled = new AbortController()
  canceled.abort()
  assert.equal((await transcribe({ signal: canceled.signal, get body() { assert.fail('canceled request parsed body') } })).status, 499)
  assert.equal((await transcribe(request(), processOptions(''))).status, 429)
  const timeout = await first
  assert.equal(timeout.status, 504)
  assert.equal(isTranscribing(), false)
  assert.equal(JSON.parse(timeout.body).error, 'transcription_timed_out')
  assert.equal((await transcribe(request(), processOptions(`process.stdin.resume(); process.stdout.write('{"text":"recovered"}');`))).status, 200)
})

test('failed spawn, invalid output and excessive output resolve and release the process slot', async () => {
  const failed = await transcribe(request(), { ready: () => true, createProcess: () => spawn('/nonexistent/afto-test-python') })
  assert.equal(failed.status, 500)
  for (const source of [
    `process.stdin.resume(); process.stdout.write('not JSON');`,
    `process.stdin.resume(); process.stdout.write('{"text":12}');`,
    `process.stdin.resume(); process.stdout.write('x'.repeat(2 * 1024 * 1024));`,
    `process.stdin.resume(); process.stderr.write('x'.repeat(2 * 1024 * 1024)); process.exitCode = 1;`
  ]) {
    assert.equal((await transcribe(request(), processOptions(source))).status, 500)
  }
  assert.equal((await transcribe(request(), processOptions(`process.stdin.resume(); process.stdout.write('{"text":"ready"}');`))).status, 200)
})
