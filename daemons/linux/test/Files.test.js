import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { Writable } from 'node:stream'
import { once } from 'node:events'
import { read } from '../src/Handlers/FilesHandler.js'

async function download(t, content, range) {
  const directory = mkdtempSync(join(tmpdir(), 'afto-files-'))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  const file = join(directory, 'fixture.bin')
  writeFileSync(file, content)
  const response = read({ query: { path: file }, headers: range ? { range } : {} })
  const chunks = []
  if (response.streamer) {
    const output = new Writable({ write(chunk, encoding, next) { chunks.push(chunk); next() } })
    const done = once(output, 'finish')
    response.streamer(output)
    await done
  }
  return { response, data: response.body ?? Buffer.concat(chunks) }
}

test('File delivery streams full bytes and advertises ranges without an in-memory response body', async (t) => {
  const { response, data } = await download(t, Buffer.alloc(2 * 1024 * 1024, 71))
  assert.equal(response.status, 200)
  assert.equal(response.body, null)
  assert.equal(response.extraHeaders['Accept-Ranges'], 'bytes')
  assert.equal(data.length, 2 * 1024 * 1024)
  assert.equal(data[10000], 71)
})

test('Byte ranges support closed, open-ended and suffix reads with clamping', async (t) => {
  for (const [range, expected, header] of [
    ['bytes=2-4', '234', 'bytes 2-4/10'],
    ['bytes=7-', '789', 'bytes 7-9/10'],
    ['bytes=-3', '789', 'bytes 7-9/10'],
    ['bytes=7-99', '789', 'bytes 7-9/10'],
    ['bytes=-99', '0123456789', 'bytes 0-9/10']
  ]) {
    const { response, data } = await download(t, '0123456789', range)
    assert.equal(response.status, 206)
    assert.equal(data.toString(), expected)
    assert.equal(response.extraHeaders['Content-Range'], header)
    assert.equal(Number(response.extraHeaders['Content-Length']), expected.length)
  }
})

test('Invalid and unsatisfiable ranges return 416 without allocating a negative or excessive buffer', async (t) => {
  for (const range of ['bytes=5-2', 'bytes=10-', 'bytes=-0', 'bytes=-', 'bytes=99999999999999999999-', 'bytes=0-1,3-4']) {
    const { response, data } = await download(t, '0123456789', range)
    assert.equal(response.status, 416, range)
    assert.equal(response.extraHeaders['Content-Range'], 'bytes */10')
    assert.equal(data.length, 0)
  }
  assert.equal((await download(t, '', 'bytes=0-')).response.status, 416)
  assert.equal((await download(t, '')).data.length, 0)
})

test('Directory listing preserves Unicode and hidden-file preference while skipping broken symlinks', async (t) => {
  const directory = mkdtempSync(join(tmpdir(), 'afto-list-'))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  const { mkdirSync, symlinkSync } = await import('node:fs')
  const { list } = await import('../src/Handlers/FilesHandler.js')
  mkdirSync(join(directory, 'folder'))
  writeFileSync(join(directory, '日本語 [a].txt'), 'hello')
  writeFileSync(join(directory, '.secret'), 'hidden')
  symlinkSync(join(directory, 'missing'), join(directory, 'broken'))
  const visible = JSON.parse((await list({ query: { path: directory } })).body)
  assert.deepEqual(visible.entries.map(item => item.name), ['folder', '日本語 [a].txt'])
  assert.equal(visible.entries[1].size, 5)
  const all = JSON.parse((await list({ query: { path: directory, showHidden: 'true' } })).body)
  assert.equal(all.entries.some(item => item.name === '.secret'), true)
  assert.equal((await list({ query: { path: join(directory, 'missing') } })).status, 404)
})

test('File search stays bounded and excludes dependency and hidden trees', async (t) => {
  const directory = mkdtempSync(join(tmpdir(), 'afto-search-'))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  const { mkdirSync } = await import('node:fs')
  const { search } = await import('../src/Handlers/FilesHandler.js')
  for (const folder of ['src', '.git', 'node_modules']) {
    mkdirSync(join(directory, folder))
    writeFileSync(join(directory, folder, 'needle.swift'), folder)
  }
  const found = JSON.parse((await search({ query: { path: directory, query: 'NEEDLE' } })).body)
  assert.deepEqual(found.entries.map(item => item.path), [join(directory, 'src', 'needle.swift')])
  for (let i = 0; i < 150; i++) writeFileSync(join(directory, `needle-${i}.txt`), '')
  const bounded = JSON.parse((await search({ query: { path: directory, query: 'needle' } })).body)
  assert.equal(bounded.entries.length, 100)
})

test('HTTP range delivery advertises exact length and can be cancelled without stopping the server', async (t) => {
  const { createServer } = await import('node:http')
  const directory = mkdtempSync(join(tmpdir(), 'afto-http-file-'))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  const file = join(directory, 'fixture.bin')
  writeFileSync(file, Buffer.alloc(8 * 1024 * 1024, 65))
  const server = createServer((request, response) => read({ query: { path: file }, headers: request.headers }).send(response))
  server.listen(0, '127.0.0.1')
  await once(server, 'listening')
  t.after(() => { server.closeAllConnections(); server.close() })
  const url = `http://127.0.0.1:${server.address().port}`
  const response = await fetch(url, { headers: { Range: 'bytes=4-9' } })
  assert.equal(response.status, 206)
  assert.equal(response.headers.get('content-length'), '6')
  assert.equal(await response.text(), 'AAAAAA')
  const controller = new AbortController()
  const large = await fetch(url, { signal: controller.signal })
  assert.equal(large.status, 200)
  controller.abort()
  const alive = await fetch(url, { headers: { Range: 'bytes=-1' } })
  assert.equal(await alive.text(), 'A')
})
