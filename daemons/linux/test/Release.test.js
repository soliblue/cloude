import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { fileURLToPath } from 'node:url'

const source = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

test('local release packaging validates versions and archives without changing source or replacing outputs', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-release-check-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  const original = fs.readFileSync(path.join(source, 'src/Version.js'), 'utf8')
  const output = path.join(root, 'cloude-linux-daemon.tar.gz')
  const script = path.join(source, 'scripts/package-release.mjs')
  for (const version of ['main', "1.2.3';exit", '1.2.3.4.5', '1.2', '1.2.3/evil']) assert.throws(() => execFileSync(process.execPath, [script, version, output], {stdio:'pipe'}))
  const result = JSON.parse(execFileSync(process.execPath, [script, '2026.09.07.1', output], {encoding:'utf8'}))
  assert.equal(result.version, '2026.09.07.1')
  assert.ok(result.files > 30)
  assert.equal(result.digest, `sha256:${createHash('sha256').update(fs.readFileSync(output)).digest('hex')}`)
  assert.equal(fs.readFileSync(`${output}.sha256`, 'utf8'), `${result.digest.slice(7)}  cloude-linux-daemon.tar.gz\n`)
  assert.equal(fs.readFileSync(path.join(source, 'src/Version.js'), 'utf8'), original)
  assert.throws(() => execFileSync(process.execPath, [script, '2026.09.07.1', output], {stdio:'pipe'}))
})
