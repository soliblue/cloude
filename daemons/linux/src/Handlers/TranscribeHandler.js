import { spawn } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import HTTPResponse from '../Networking/HTTPResponse.js'

const root = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))))
const pythonPath = path.join(root, 'whisper-env', 'bin', 'python3')
const scriptPath = path.join(root, 'scripts', 'transcribe.py')

export function transcriptionReady() {
  return fs.existsSync(pythonPath) && fs.existsSync(scriptPath)
}

function parsedBody(request) {
  try {
    return JSON.parse(request.body.toString('utf8'))
  } catch {
    return null
  }
}

export function transcribe(request) {
  const body = parsedBody(request)
  if (typeof body?.audio !== 'string' || body.audio.length === 0) {
    return HTTPResponse.json(400, { error: 'missing_audio' })
  }
  if (!transcriptionReady()) {
    return HTTPResponse.json(503, { error: 'transcription_unavailable' })
  }
  return new Promise((resolve) => {
    const child = spawn(pythonPath, [scriptPath])
    let out = ''
    let err = ''
    child.stdout.on('data', (chunk) => {
      out += chunk
    })
    child.stderr.on('data', (chunk) => {
      err += chunk
    })
    child.on('error', (error) => {
      console.error(`Transcribe: spawn_failed ${error.message}`)
      resolve(HTTPResponse.json(500, { error: 'transcription_failed' }))
    })
    child.on('close', (code) => {
      if (code === 0) {
        let parsed = null
        try {
          parsed = JSON.parse(out)
        } catch {
          parsed = null
        }
        if (parsed && typeof parsed.text === 'string') {
          resolve(HTTPResponse.json(200, { text: parsed.text }))
        } else {
          resolve(HTTPResponse.json(500, { error: 'transcription_failed' }))
        }
      } else {
        console.error(`Transcribe: exit=${code} stderr=${err.slice(0, 200)}`)
        resolve(HTTPResponse.json(500, { error: 'transcription_failed' }))
      }
    })
    child.stdin.write(body.audio)
    child.stdin.end()
  })
}
