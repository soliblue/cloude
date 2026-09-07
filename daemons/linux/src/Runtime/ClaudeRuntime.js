import fs from 'node:fs'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import SubscriptionPolicy from './SubscriptionPolicy.js'
import os from 'node:os'
import path from 'node:path'

const candidateDirectories = [
  '/opt/homebrew/bin',
  '/usr/local/bin',
  '/usr/bin',
  path.join(os.homedir(), '.local', 'bin'),
  path.join(os.homedir(), '.npm-global', 'bin')
]

export function claudeCommand() {
  const directories = [...(process.env.PATH || '').split(':').filter(Boolean), ...candidateDirectories]
  for (const directory of directories) {
    const candidate = path.join(directory, 'claude')
    if (fs.existsSync(candidate)) {
      return { executable: candidate, leadingArguments: [] }
    }
  }
  return { executable: '/usr/bin/env', leadingArguments: ['claude'] }
}

export function spawnEnvironment() {
  const environment = {}
  for (const key of ['HOME', 'USER', 'SHELL', 'LANG', 'LC_ALL', 'TMPDIR', 'TERM']) {
    if (process.env[key]) {
      environment[key] = process.env[key]
    }
  }
  const pathParts = [...(process.env.PATH || '').split(':').filter(Boolean), ...candidateDirectories]
  environment.PATH = [...new Set(pathParts)].join(':')
  environment.TERM = environment.TERM || 'xterm-256color'
  environment.NO_COLOR = '1'
  environment.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = '1'
  return environment
}

export const subscriptionSettings = JSON.stringify({ forceLoginMethod: 'claudeai' })

export function requireClaudeConfiguration(cwd, { home = os.homedir(), managedPaths = ['/etc/claude-code/managed-settings.json', '/Library/Application Support/ClaudeCode/managed-settings.json'] } = {}) {
  const settingsFiles = [path.join(home, '.claude', 'settings.json'), ...managedPaths]
  for (const file of managedPaths) {
    const fragments = path.join(path.dirname(file), 'managed-settings.d')
    if (fs.existsSync(fragments)) {
      for (const name of fs.readdirSync(fragments).filter(name => name.endsWith('.json') && !name.startsWith('.'))) {
        settingsFiles.push(path.join(fragments, name))
      }
    }
  }
  let directory = fs.realpathSync(cwd)
  while (true) {
    settingsFiles.push(path.join(directory, '.claude', 'settings.json'), path.join(directory, '.claude', 'settings.local.json'))
    if (directory === path.dirname(directory)) { break }
    directory = path.dirname(directory)
  }
  for (const file of new Set(settingsFiles)) {
    if (fs.existsSync(file)) {
      let settings
      try { settings = JSON.parse(fs.readFileSync(file, 'utf8')) } catch {
        throw new Error('Claude settings could not be verified for subscription-only mode.')
      }
      SubscriptionPolicy.claudeSettings(settings)
    }
  }
}

export async function requireClaudeSubscription(cwd) {
  requireClaudeConfiguration(cwd)
  const { executable, leadingArguments } = claudeCommand()
  const result = await promisify(execFile)(executable, [...leadingArguments, '--settings', subscriptionSettings, 'auth', 'status'], { cwd, env: spawnEnvironment(), timeout: 15000, maxBuffer: 1024 * 1024 }).catch(() => ({ stdout: '{}' }))
  SubscriptionPolicy.claude(JSON.parse(result.stdout))
}
