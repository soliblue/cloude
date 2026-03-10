import { spawn } from 'child_process'
import { join } from 'path'
import * as pty from 'node-pty'
import { log } from './log.js'

const WHISPER_PYTHON = join(import.meta.dirname, 'whisper-env', 'bin', 'python3')
const WHISPER_SCRIPT = join(import.meta.dirname, 'transcribe.py')

const IDLE_TIMEOUT_MS = 10 * 60 * 1000

const activeTerminals = new Map()

export function handleTranscribe(audioBase64, ws, sendTo) {
  if (!audioBase64) {
    sendTo(ws, { type: 'error', message: 'No audio data provided' })
    return
  }

  log('Transcribing audio...')
  const proc = spawn(WHISPER_PYTHON, [WHISPER_SCRIPT])
  let stdout = ''
  let stderr = ''

  proc.stdout.on('data', d => { stdout += d })
  proc.stderr.on('data', d => { stderr += d })
  proc.stdin.write(audioBase64)
  proc.stdin.end()

  proc.on('close', code => {
    if (code !== 0) {
      log(`Transcription failed: ${stderr}`)
      sendTo(ws, { type: 'error', message: `Transcription failed: ${stderr.slice(0, 200)}` })
      return
    }
    try {
      const result = JSON.parse(stdout)
      log(`Transcribed: "${result.text?.slice(0, 50)}..."`)
      sendTo(ws, { type: 'transcription', text: result.text || '' })
    } catch (e) {
      sendTo(ws, { type: 'error', message: 'Failed to parse transcription result' })
    }
  })
}

function killEntry(entry) {
  clearTimeout(entry.timeout)
  entry.proc.kill()
}

function terminalKey(terminalId, ws) {
  return terminalId || `ws-${ws._socket?.remotePort || 'unknown'}`
}

function resetIdleTimeout(key) {
  const entry = activeTerminals.get(key)
  if (!entry) return
  if (Date.now() - (entry.lastReset || 0) < 5000) return
  entry.lastReset = Date.now()
  clearTimeout(entry.timeout)
  entry.timeout = setTimeout(() => {
    log(`Terminal idle timeout - killing PTY (${key.slice(0, 12)})`)
    entry.proc.kill()
    activeTerminals.delete(key)
  }, IDLE_TIMEOUT_MS)
}

export function handleTerminalExec(command, workingDirectory, terminalId, ws, sendTo) {
  const cwd = workingDirectory ? workingDirectory.replace(/^~/, process.env.HOME) : process.env.HOME
  const key = terminalKey(terminalId, ws)
  log(`Terminal exec: ${command} (cwd: ${cwd}, id: ${key.slice(0, 12)})`)

  const existing = activeTerminals.get(key)
  if (existing) {
    killEntry(existing)
    activeTerminals.delete(key)
  }

  const proc = pty.spawn('bash', ['-c', command], {
    name: 'xterm-256color',
    cols: 80,
    rows: 24,
    cwd,
    env: { ...process.env, TERM: 'xterm-256color', FORCE_COLOR: '1', CLICOLOR_FORCE: '1' }
  })

  activeTerminals.set(key, { proc, ws, timeout: null })
  resetIdleTimeout(key)

  proc.onData(data => {
    resetIdleTimeout(key)
    sendTo(ws, { type: 'terminal_output', output: data, exitCode: null, isError: false, terminalId: terminalId || undefined })
  })

  proc.onExit(({ exitCode }) => {
    const entry = activeTerminals.get(key)
    if (entry) clearTimeout(entry.timeout)
    activeTerminals.delete(key)
    sendTo(ws, { type: 'terminal_output', output: '', exitCode: exitCode ?? 0, isError: (exitCode ?? 0) !== 0, terminalId: terminalId || undefined })
  })
}

export function handleTerminalInput(text, terminalId, ws) {
  const key = terminalKey(terminalId, ws)
  const entry = activeTerminals.get(key)
  if (entry) {
    resetIdleTimeout(key)
    entry.proc.write(text)
  }
}

export function cleanupTerminal(ws) {
  for (const [key, entry] of activeTerminals) {
    if (entry.ws === ws) {
      killEntry(entry)
      activeTerminals.delete(key)
    }
  }
}
