import { spawn } from 'child_process'
import { join } from 'path'
import { log } from './log.js'

const WHISPER_PYTHON = join(import.meta.dirname, 'whisper-env', 'bin', 'python3')
const WHISPER_SCRIPT = join(import.meta.dirname, 'transcribe.py')

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

export function handleTerminalExec(command, workingDirectory, ws, sendTo) {
  const cwd = workingDirectory ? workingDirectory.replace(/^~/, process.env.HOME) : process.env.HOME
  log(`Terminal exec: ${command} (cwd: ${cwd})`)

  const proc = spawn('bash', ['-c', command], { cwd, env: { ...process.env, TERM: 'xterm-256color', FORCE_COLOR: '1', CLICOLOR_FORCE: '1' } })
  let stdout = ''
  let stderr = ''

  proc.stdout.on('data', d => { stdout += d })
  proc.stderr.on('data', d => { stderr += d })

  proc.on('close', code => {
    const output = stdout + (stderr ? (stdout ? '\n' : '') + stderr : '')
    sendTo(ws, { type: 'terminal_output', output, exitCode: code, isError: code !== 0 })
  })

  proc.on('error', err => {
    sendTo(ws, { type: 'terminal_output', output: err.message, exitCode: 1, isError: true })
  })
}
