import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

test('upgrading reuses the private identity, bearer token and tunnel without a provisioning call', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-provision-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  const identity = JSON.stringify({ installationId: 'fixture-installation', secret: 'fixture-secret' })
  const tunnel = JSON.stringify({ hostname: 'fixture.example.test', tunnelToken: 'fixture-tunnel-token' })
  fs.writeFileSync(path.join(root, 'identity.json'), identity)
  fs.writeFileSync(path.join(root, 'tunnel.json'), tunnel)
  fs.writeFileSync(path.join(root, 'auth-token'), 'fixture-bearer')
  const result = JSON.parse(execFileSync(process.execPath, [path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../scripts/provision.js')], { env: { ...process.env, CLOUDE_DATA: root, CLOUDE_PROVISIONING_URL: 'http://127.0.0.1:1', CLOUDE_REPROVISION: '0' }, encoding: 'utf8' }))
  const pairing = new URL(result.pairingURL)
  assert.equal(pairing.protocol, 'cloude:')
  assert.equal(pairing.searchParams.get('host'), 'fixture.example.test')
  assert.equal(pairing.searchParams.get('port'), '443')
  assert.equal(pairing.searchParams.get('token'), 'fixture-bearer')
  assert.equal(fs.readFileSync(path.join(root, 'identity.json'), 'utf8'), identity)
  assert.equal(fs.readFileSync(path.join(root, 'tunnel.json'), 'utf8'), tunnel)
})
