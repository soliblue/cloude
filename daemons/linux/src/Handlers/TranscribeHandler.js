import { spawn } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import HTTPResponse from '../Networking/HTTPResponse.js'

const root = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const pythonPath = path.join(root, 'whisper-env', 'bin', 'python3')
const scriptPath = path.join(root, 'scripts', 'transcribe.py')
let active = false

export function isTranscribing() {
  return active
}

export function transcriptionReady() {
  return fs.existsSync(pythonPath) && fs.existsSync(scriptPath)
}

function parsedJSON(data) {
  try {
    return JSON.parse(data.toString('utf8'))
  } catch {
    return null
  }
}

export function transcribe(request, { createProcess = spawn, ready = transcriptionReady, timeout = 55_000 } = {}) {
  if (request.signal?.aborted) {
    return HTTPResponse.json(499, { error: 'transcription_canceled' })
  }
  if (active) {
    return HTTPResponse.json(429, { error: 'transcription_busy' })
  }
  const body = parsedJSON(request.body)
  if (typeof body?.audio !== 'string' || body.audio.length === 0) {
    return HTTPResponse.json(400, { error: 'missing_audio' })
  }
  if (body.audio.length > 16 * 1024 * 1024) {
    return HTTPResponse.json(413, { error: 'audio_too_large' })
  }
  if (Buffer.from(body.audio, 'base64').toString('base64') !== body.audio) {
    return HTTPResponse.json(400, { error: 'invalid_audio' })
  }
  if (!ready()) {
    return HTTPResponse.json(503, { error: 'transcription_unavailable' })
  }
  return new Promise((resolve) => {
    const child = createProcess(pythonPath, [scriptPath], { timeout, killSignal: 'SIGKILL' })
    active = true
    const chunks = []
    let size = 0
    let failed = false
    const cancel = () => { child.kill('SIGKILL') }
    request.signal?.addEventListener('abort', cancel, { once: true })
    if (request.signal?.aborted) { cancel() }
    child.stdout.on('data', (chunk) => {
      size += chunk.length
      if (size <= 1024 * 1024) {
        chunks.push(chunk)
      } else {
        failed = true
        child.kill('SIGKILL')
      }
    })
    child.stderr.resume()
    child.on('error', () => { failed = true })
    child.on('close', (code, signal) => {
      active = false
      request.signal?.removeEventListener('abort', cancel)
      const parsed = code === 0 && !failed && !signal ? parsedJSON(Buffer.concat(chunks)) : null
      if (request.signal?.aborted) {
        resolve(HTTPResponse.json(499, { error: 'transcription_canceled' }))
      } else if (parsed && typeof parsed.text === 'string') {
        resolve(HTTPResponse.json(200, { text: parsed.text }))
      } else {
        resolve(HTTPResponse.json(signal && !failed ? 504 : 500, {
          error: signal && !failed ? 'transcription_timed_out' : 'transcription_failed'
        }))
      }
    })
    child.stdin.on('error', () => { failed = true })
    child.stdin.end(body.audio)
  })
}
