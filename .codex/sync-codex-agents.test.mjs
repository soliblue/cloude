import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

test('generated TOML preserves literal backslashes, Markdown pipes and quote delimiters', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-agent-escape-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  const source = path.join(root, 'source')
  const output = path.join(root, 'output')
  fs.mkdirSync(source)
  const body = String.raw`Use <route\|full-url>, regex \d+\n and C:\work\file.
A literal triple quote: """ and four: """".
A trailing backslash: \
Next line must remain separate.`
  fs.writeFileSync(path.join(source, 'escape.md'), `---\nname: escape\ndescription: Backslash regression\n---\n${body}\n`)
  execFileSync(process.execPath, [fileURLToPath(new URL('./sync-codex-agents-from-claude.mjs', import.meta.url)), '--source', source, '--output', output])
  const parsed = JSON.parse(execFileSync('python3', ['-c', 'import json,sys,tomllib; print(json.dumps(tomllib.load(open(sys.argv[1],"rb"))))', path.join(output, 'escape.toml')], { encoding: 'utf8' }))
  assert.equal(parsed.developer_instructions, `${body}\n`)
  const previous = fs.readFileSync(path.join(output, 'escape.toml'), 'utf8')
  execFileSync(process.execPath, [fileURLToPath(new URL('./sync-codex-agents-from-claude.mjs', import.meta.url)), '--source', source, '--output', output])
  assert.equal(fs.readFileSync(path.join(output, 'escape.toml'), 'utf8'), previous)
})
