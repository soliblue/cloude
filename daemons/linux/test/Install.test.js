import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const source = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

test('installer preserves data and voice models, uses invoking account, and removes only its own services', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-install-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  const bin = path.join(root, 'bin')
  const install = path.join(root, 'app')
  const data = path.join(root, 'data')
  const units = path.join(root, 'units')
  for (const directory of [bin, install, data, units, path.join(install, 'whisper-env')]) { fs.mkdirSync(directory, { recursive: true }) }
  fs.writeFileSync(path.join(data, 'auth-token'), 'existing-token')
  fs.writeFileSync(path.join(data, 'identity.json'), 'existing-identity')
  fs.writeFileSync(path.join(data, 'history.jsonl'), 'existing-history')
  fs.writeFileSync(path.join(install, 'whisper-env', 'proof'), 'existing-model')
  for (const command of ['sudo', 'node', 'uname', 'id', 'npm', 'codex', 'cloudflared', 'systemctl', 'qrencode', 'flock']) {
    fs.writeFileSync(path.join(bin, command), `#!/bin/bash\ncase "$(basename "$0")" in\nsudo) exec "$@" ;;\nuname) [ "$1" = -s ] && echo Linux || echo x86_64 ;;\nid) case "$1" in -u) echo "\${TEST_UID:-1000}" ;; -un) echo "$(id -un)" ;; -gn) echo "$(id -gn)" ;; esac ;;\nnode) if [[ "\${1:-}" = */scripts/provision.js ]]; then echo '{"pairingURL":"cloude://pair?host=example.test&port=443&token=fixture"}'; else exec "${process.execPath}" "$@"; fi ;;\n*) printf '%s %s\\n' "$(basename "$0")" "$*" >> "$TEST_LOG" ;;\nesac\n`.replaceAll('"$(id -un)"', JSON.stringify(execFileSync('id', ['-un'], { encoding: 'utf8' }).trim())).replaceAll('"$(id -gn)"', JSON.stringify(execFileSync('id', ['-gn'], { encoding: 'utf8' }).trim())), { mode: 0o755 })
  }
  const env = { ...process.env, PATH: `${bin}:${process.env.PATH}`, HOME: root, CLOUDE_INSTALL_DIR: install, CLOUDE_DATA: data, CLOUDE_SYSTEMD_DIR: units, TEST_LOG: path.join(root, 'calls') }
  execFileSync('bash', [path.join(source, 'install.sh')], { env, cwd: root })
  fs.chmodSync(path.join(install, 'index.js'), 0o400)
  execFileSync('bash', [path.join(source, 'install.sh')], { env, cwd: root })
  assert.equal(fs.readFileSync(path.join(data, 'auth-token'), 'utf8'), 'existing-token')
  assert.equal(fs.readFileSync(path.join(data, 'identity.json'), 'utf8'), 'existing-identity')
  assert.equal(fs.readFileSync(path.join(data, 'history.jsonl'), 'utf8'), 'existing-history')
  assert.equal(fs.readFileSync(path.join(install, 'whisper-env', 'proof'), 'utf8'), 'existing-model')
  assert.equal(fs.statSync(data).mode & 0o777, 0o700)
  assert.ok(fs.statSync(path.join(install, 'index.js')).mode & 0o200)
  const unit = fs.readFileSync(path.join(units, 'cloude-agent.service'), 'utf8')
  assert.match(unit, /CLOUDE_HOST=127.0.0.1/)
  assert.ok(!unit.includes('fuser'))
  assert.match(unit, /Restart=always/)
  assert.match(unit, new RegExp(`User=${execFileSync('id', ['-un'], { encoding: 'utf8' }).trim()}`))
  fs.writeFileSync(path.join(units, 'cloude-tunnel.service'), 'ExecStart=/opt/another-daemon/tunnel\n')
  execFileSync('bash', [path.join(source, 'scripts/uninstall.sh')], { env })
  assert.equal(fs.existsSync(path.join(units, 'cloude-agent.service')), false)
  assert.equal(fs.existsSync(path.join(units, 'cloude-tunnel.service')), true)
  assert.equal(fs.existsSync(path.join(data, 'auth-token')), true)
  const calls = fs.readFileSync(env.TEST_LOG, 'utf8')
  assert.match(calls, /systemctl disable --now cloude-agent/)
  assert.ok(!calls.includes('systemctl disable --now cloude-tunnel'))
  assert.throws(() => execFileSync('bash', [path.join(source, 'install.sh')], { env: { ...env, TEST_UID: '0' } }), /Command failed/)
})

test('cloudflared is installed only after its release digest matches downloaded bytes', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-tunnel-install-'))
  t.after(() => fs.rmSync(root, {recursive:true,force:true}))
  const bin = path.join(root,'bin')
  fs.mkdirSync(bin)
  const script = `#!/bin/bash
case "$(basename "$0")" in
uname) [ "$1" = -s ] && echo Linux || echo x86_64 ;;
id) case "$1" in -u) echo 1000 ;; -un) echo ${execFileSync('id',['-un'],{encoding:'utf8'}).trim()} ;; -gn) echo ${execFileSync('id',['-gn'],{encoding:'utf8'}).trim()} ;; esac ;;
sudo) if [ "$1" = install ]; then echo verified-install >> "$TEST_LOG"; else exec "$@"; fi ;;
codex) echo 'codex-cli 0.153.4' ;;
npm|systemctl) exit 0 ;;
node) if [[ "$*" == *api.github.com/repos/cloudflare/cloudflared* ]]; then
  "${process.execPath}" -e 'process.stdout.write("https://github.com/cloudflare/cloudflared/releases/download/fixture/cloudflared-linux-amd64 "+require("node:crypto").createHash("sha256").update("verified-binary").digest("hex"))'
  elif [[ "\${1:-}" = */scripts/provision.js ]]; then echo '{"pairingURL":"cloude://pair?host=fixture.test&port=443&token=fixture"}'
  else exec "${process.execPath}" "$@"; fi ;;
curl) while [ "$#" -gt 0 ]; do if [ "$1" = -o ]; then shift; printf '%s' "$TEST_DOWNLOAD" > "$1"; break; fi; shift; done ;;
sha256sum) exec "${process.execPath}" -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{const [digest,file]=s.trim().split(/  /);process.exit(require("node:crypto").createHash("sha256").update(require("node:fs").readFileSync(file)).digest("hex")===digest?0:1)})' ;;
esac
`
  for(const name of ['uname','id','sudo','codex','npm','systemctl','node','curl','sha256sum','flock']) fs.writeFileSync(path.join(bin,name),script,{mode:0o755})
  const env={...process.env,PATH:`${bin}:/usr/bin:/bin:/usr/sbin:/sbin`,HOME:root,CLOUDE_INSTALL_DIR:path.join(root,'app'),CLOUDE_DATA:path.join(root,'data'),CLOUDE_SYSTEMD_DIR:path.join(root,'units'),TEST_LOG:path.join(root,'calls'),TEST_DOWNLOAD:'tampered-binary'}
  assert.throws(()=>execFileSync('bash',[path.join(source,'install.sh')],{env,stdio:'pipe'}))
  assert.equal(fs.existsSync(env.TEST_LOG),false)
  execFileSync('bash',[path.join(source,'install.sh')],{env:{...env,TEST_DOWNLOAD:'verified-binary'},stdio:'pipe'})
  assert.equal(fs.readFileSync(env.TEST_LOG,'utf8'),'verified-install\n')
})
