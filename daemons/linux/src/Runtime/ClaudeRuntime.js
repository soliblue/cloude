import fs from 'node:fs'
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
