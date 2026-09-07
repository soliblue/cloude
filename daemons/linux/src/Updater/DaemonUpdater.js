import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'
import { gunzipSync } from 'node:zlib'
import { DAEMON_VERSION, IS_DEV } from '../Version.js'
import { runnerManager } from '../RunnerManager.js'
import { codexClient } from '../Codex/CodexClient.js'
import { codexSessions } from '../Codex/CodexSessions.js'
import { codexCompaction } from '../Codex/CodexCompaction.js'
import { codexTerminal } from '../Codex/CodexTerminal.js'
import { agentSchedules } from '../Codex/AgentSchedules.js'
import { isTranscribing } from '../Handlers/TranscribeHandler.js'
import { isReleaseVersion } from '../ReleaseVersion.js'

const entries = ['src', 'scripts', 'index.js', 'package.json', 'package-lock.json', 'install.sh', 'README.md']
const installDirectory = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')

export function latestRelease(releases) {
  return releases.filter((candidate) => !candidate.draft && !candidate.prerelease && typeof candidate.tag_name === 'string' && candidate.tag_name.startsWith('linux-daemon-v') && isReleaseVersion(candidate.tag_name.slice('linux-daemon-v'.length))).sort((a, b) => b.tag_name.localeCompare(a.tag_name, undefined, { numeric: true }))[0]
}

export function releaseFiles(archive, version) {
  if (!isReleaseVersion(version)) { throw new Error('Invalid daemon release version') }
  const tar = gunzipSync(archive, { maxOutputLength: 64 * 1024 * 1024 })
  const files = new Map()
  for (let offset = 0; offset + 512 <= tar.length && tar[offset] !== 0;) {
    const header = tar.subarray(offset, offset + 512)
    const name = header.subarray(0, 100).toString().replace(/\0.*$/s, '')
    const prefix = header.subarray(345, 500).toString().replace(/\0.*$/s, '')
    const size = Number.parseInt(header.subarray(124, 136).toString().replace(/\0.*$/s, '').trim(), 8)
    const type = header[156]
    const fullName = prefix ? `${prefix}/${name}` : name
    const relative = fullName.replace(/^release\//, '').replace(/\/$/, '')
    if (!Number.isSafeInteger(size) || size < 0 || offset + 512 + size > tar.length || ![0, 48, 53].includes(type) || !fullName.startsWith('release/') || (relative && (!entries.includes(relative.split('/')[0]) || relative.split('/').some((part) => !part || part === '.' || part === '..') || relative.includes('\\')))) {
      throw new Error('Release archive contains unsupported paths or entries')
    }
    if (type !== 53 && relative) {
      if (files.has(relative)) { throw new Error('Release archive has duplicate files') }
      files.set(relative, tar.subarray(offset + 512, offset + 512 + size))
    }
    offset += 512 + Math.ceil(size / 512) * 512
  }
  const pkg = JSON.parse(files.get('package.json')?.toString() || '{}')
  if (!files.has('index.js') || !files.has('src/Version.js') || !files.has('scripts/run-tunnel.sh') || pkg.type !== 'module' || Object.keys(pkg.dependencies || {}).length || Object.keys(pkg.optionalDependencies || {}).length || !files.get('src/Version.js').toString().includes(`export const DAEMON_VERSION = '${version}'`)) {
    throw new Error('Release is incomplete, has unbundled dependencies, or has a mismatched version')
  }
  return files
}

export function isIdle() {
  return runnerManager.runners.size === 0 && !isTranscribing()
    && ![...codexTerminal.entries.values()].some(entry => entry.status === 'running')
    && ![...codexTerminal.starts.values()].some(entry => !entry.terminalId)
    && ![...codexCompaction.states.values()].some(entry => entry.state.status === 'pending')
    && agentSchedules.active.size === 0
    && !agentSchedules.store.state.runs.some(run => ['starting', 'running', 'waiting'].includes(run.status))
    && codexClient.pending.size === 0 && codexClient.serverRequests.size === 0 && codexClient.activeTurns.size === 0
    && codexSessions.mutations.size === 0 && codexSessions.steering.size === 0
}

export function applyRelease(directory, files, idle = isIdle, restart = () => {}) {
  const staging = fs.mkdtempSync(path.join(directory, '.update-'))
  const replaced = []
  let safeToRemove = true
  try {
    for (const [name, content] of files) {
      fs.mkdirSync(path.dirname(path.join(staging, 'new', name)), { recursive: true, mode: 0o700 })
      fs.writeFileSync(path.join(staging, 'new', name), content, { mode: name.endsWith('.sh') ? 0o700 : 0o600 })
    }
    fs.mkdirSync(path.join(staging, 'old'))
    if (!idle()) { return false }
    for (const entry of entries) {
      if (fs.existsSync(path.join(staging, 'new', entry))) {
        if (fs.existsSync(path.join(directory, entry))) {
          fs.renameSync(path.join(directory, entry), path.join(staging, 'old', entry))
        }
        replaced.push(entry)
        fs.renameSync(path.join(staging, 'new', entry), path.join(directory, entry))
      }
    }
  } catch (error) {
    safeToRemove = false
    for (const entry of replaced.reverse()) {
      fs.rmSync(path.join(directory, entry), { recursive: true, force: true })
      if (fs.existsSync(path.join(staging, 'old', entry))) { fs.renameSync(path.join(staging, 'old', entry), path.join(directory, entry)) }
    }
    safeToRemove = true
    throw error
  } finally { if (safeToRemove) { fs.rmSync(staging, { recursive: true, force: true }) } }
  restart()
  return true
}

export async function checkOnce() {
  if (IS_DEV || !process.env.INVOCATION_ID || !isIdle() || process.env.CLOUDE_AUTO_UPDATE === '0') { return false }
  const response = await fetch('https://api.github.com/repos/soliblue/cloude/releases?per_page=100', { headers: { Accept: 'application/vnd.github+json' }, signal: AbortSignal.timeout(15000) })
  if (!response.ok) { throw new Error(`Release lookup failed (${response.status})`) }
  const release = latestRelease(await response.json())
  const version = release?.tag_name.replace('linux-daemon-v', '')
  if (!version || version.localeCompare(DAEMON_VERSION, undefined, { numeric: true }) <= 0) { return false }
  const asset = release.assets?.find((candidate) => candidate.name === 'cloude-linux-daemon.tar.gz')
  if (!asset || !/^sha256:[a-f0-9]{64}$/.test(asset.digest || '') || !asset.browser_download_url.startsWith('https://github.com/soliblue/cloude/releases/download/')) { throw new Error('Release asset has no verifiable SHA256 digest') }
  const download = await fetch(asset.browser_download_url, { signal: AbortSignal.timeout(60000) })
  if (!download.ok || !download.body) { throw new Error(`Release download failed (${download.status})`) }
  const chunks = []
  let bytes = 0
  for await (const chunk of download.body) {
    bytes += chunk.length
    if (bytes > 32 * 1024 * 1024) { throw new Error('Release archive exceeds 32 MiB') }
    chunks.push(chunk)
  }
  const archive = Buffer.concat(chunks)
  if (`sha256:${createHash('sha256').update(archive).digest('hex')}` !== asset.digest) { throw new Error('Release checksum mismatch') }
  applyRelease(installDirectory, releaseFiles(archive, version), isIdle, () => {
    console.log(`[DaemonUpdater] installed ${version}; restarting idle systemd service`)
    process.exit(0)
  })
  return false
}

export function startDaemonUpdater() {
  if (!IS_DEV && process.env.INVOCATION_ID && process.env.CLOUDE_AUTO_UPDATE !== '0') {
    checkOnce().catch((error) => console.log(`[DaemonUpdater] update deferred: ${error.message}`))
    setInterval(() => checkOnce().catch((error) => console.log(`[DaemonUpdater] update deferred: ${error.message}`)), 6 * 60 * 60 * 1000).unref()
  }
}
