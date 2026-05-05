import { spawn } from 'child_process'
import { mkdtemp, rename, rm, writeFile, chmod, readdir, stat } from 'fs/promises'
import { createWriteStream } from 'fs'
import { tmpdir } from 'os'
import { join, dirname } from 'path'
import { pipeline } from 'stream/promises'
import { fileURLToPath } from 'url'
import { DAEMON_VERSION, IS_DEV } from '../Version.js'

const REPO = 'Soli/cloude'
const ASSET_NAME = 'cloude-linux-daemon.tar.gz'
const TAG_PREFIX = 'linux-daemon-v'
const POLL_INTERVAL_MS = 6 * 60 * 60 * 1000

export function startDaemonUpdater() {
  if (IS_DEV) return
  checkOnce().catch(() => {})
  setInterval(() => checkOnce().catch(() => {}), POLL_INTERVAL_MS)
}

async function checkOnce() {
  const release = await fetchLatestRelease()
  if (!release || !isNewer(release.version, DAEMON_VERSION)) return
  const assetURL = release.assetURL
  if (!assetURL) return
  const installDir = resolveInstallDir()
  if (!installDir) return
  const archivePath = await download(assetURL)
  if (!archivePath) return
  const extractDir = await extract(archivePath)
  if (!extractDir) return
  await swapAndRestart(installDir, extractDir)
}

async function fetchLatestRelease() {
  const response = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=20`, {
    headers: { Accept: 'application/vnd.github+json' },
  })
  if (!response.ok) return null
  const releases = await response.json()
  for (const release of releases) {
    if (typeof release.tag_name === 'string' && release.tag_name.startsWith(TAG_PREFIX)) {
      const version = release.tag_name.slice(TAG_PREFIX.length)
      const asset = (release.assets || []).find((a) => a.name === ASSET_NAME)
      return { version, assetURL: asset ? asset.browser_download_url : null }
    }
  }
  return null
}

function isNewer(candidate, current) {
  if (current === 'dev') return false
  const a = candidate.split('.').map((n) => parseInt(n, 10) || 0)
  const b = current.split('.').map((n) => parseInt(n, 10) || 0)
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const x = a[i] || 0
    const y = b[i] || 0
    if (x > y) return true
    if (x < y) return false
  }
  return false
}

function resolveInstallDir() {
  const here = dirname(fileURLToPath(import.meta.url))
  const projectRoot = join(here, '..', '..')
  return projectRoot
}

async function download(url) {
  const response = await fetch(url)
  if (!response.ok || !response.body) return null
  const dir = await mkdtemp(join(tmpdir(), 'daemon-update-'))
  const archivePath = join(dir, 'release.tar.gz')
  await pipeline(response.body, createWriteStream(archivePath))
  return archivePath
}

async function extract(archivePath) {
  const dir = await mkdtemp(join(tmpdir(), 'daemon-extract-'))
  await new Promise((resolve, reject) => {
    const child = spawn('tar', ['-xzf', archivePath, '-C', dir])
    child.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(`tar exit ${code}`))))
    child.on('error', reject)
  }).catch(() => null)
  const entries = await readdir(dir)
  const releaseDir = entries.find((e) => e === 'release')
  return releaseDir ? join(dir, releaseDir) : dir
}

async function swapAndRestart(installDir, extractDir) {
  const stagingDir = `${installDir}.new-${Date.now()}`
  const oldDir = `${installDir}.old-${Date.now()}`
  await rename(extractDir, stagingDir).catch(async () => {
    await new Promise((resolve, reject) => {
      const child = spawn('cp', ['-r', extractDir, stagingDir])
      child.on('exit', (code) => (code === 0 ? resolve() : reject()))
    })
  })
  await runNpmInstall(stagingDir)
  const scriptPath = join(tmpdir(), `daemon-swap-${Date.now()}.sh`)
  const pid = process.pid
  const script = `#!/bin/bash
while kill -0 ${pid} 2>/dev/null; do sleep 0.2; done
mv "${installDir}" "${oldDir}"
mv "${stagingDir}" "${installDir}"
rm -rf "${oldDir}"
rm -f "${scriptPath}"
`
  await writeFile(scriptPath, script)
  await chmod(scriptPath, 0o755)
  spawn('/bin/bash', [scriptPath], { detached: true, stdio: 'ignore' }).unref()
  process.exit(0)
}

async function runNpmInstall(dir) {
  const pkgPath = join(dir, 'package.json')
  if (!(await stat(pkgPath).catch(() => null))) return
  await new Promise((resolve) => {
    const child = spawn('npm', ['install', '--omit=dev'], { cwd: dir, stdio: 'ignore' })
    child.on('exit', () => resolve())
    child.on('error', () => resolve())
  })
}
