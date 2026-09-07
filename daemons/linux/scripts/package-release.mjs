import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { isReleaseVersion } from '../src/ReleaseVersion.js'

const version = process.argv[2]
const output = process.argv[3] && path.resolve(process.argv[3])
if (!isReleaseVersion(version) || !output) {
  throw new Error('Usage: node scripts/package-release.mjs VERSION /absolute/output/cloude-linux-daemon.tar.gz')
}
if (fs.existsSync(output) || fs.existsSync(`${output}.sha256`)) { throw new Error('Release output already exists; choose a new output directory.') }
const source = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-linux-package-'))
try {
  process.env.CLOUDE_DATA = path.join(temporary, 'state')
  const { releaseFiles } = await import('../src/Updater/DaemonUpdater.js')
  fs.mkdirSync(path.join(temporary, 'release'))
  for (const entry of ['src', 'scripts', 'index.js', 'package.json', 'package-lock.json', 'install.sh', 'README.md']) {
    fs.cpSync(path.join(source, entry), path.join(temporary, 'release', entry), { recursive: true, dereference: false })
  }
  const versionFile = path.join(temporary, 'release/src/Version.js')
  const original = fs.readFileSync(versionFile, 'utf8')
  if (!/^export const DAEMON_VERSION = '[^']+'$/mu.test(original)) { throw new Error('Cannot locate the daemon version declaration.') }
  fs.writeFileSync(versionFile, original.replace(/^export const DAEMON_VERSION = '[^']+'$/mu, `export const DAEMON_VERSION = '${version}'`))
  const archive = execFileSync('tar', ['--format=ustar', '-czf', '-', '-C', temporary, 'release'], { env: { ...process.env, COPYFILE_DISABLE: '1' }, maxBuffer: 32 * 1024 * 1024 })
  const files = releaseFiles(archive, version)
  fs.mkdirSync(path.dirname(output), { recursive: true })
  fs.writeFileSync(output, archive, { flag: 'wx' })
  const digest = createHash('sha256').update(archive).digest('hex')
  fs.writeFileSync(`${output}.sha256`, `${digest}  ${path.basename(output)}\n`, { flag: 'wx' })
  console.log(JSON.stringify({ version, output, digest: `sha256:${digest}`, files: files.size }))
} finally {
  fs.rmSync(temporary, { recursive: true, force: true })
}
