import { WebSocketServer } from 'ws'
import { log } from './log.js'
import { handleMessage } from './handlers.js'
import { RunnerManager } from './runner.js'

export function createServer(port, token, dataDir) {
  const wss = new WebSocketServer({ port })
  const authenticated = new Set()
  const manager = new RunnerManager()

  function broadcast(msg) {
    const data = JSON.stringify(msg)
    for (const client of wss.clients) {
      if (authenticated.has(client) && client.readyState === 1) {
        client.send(data)
      }
    }
  }

  function sendTo(ws, msg) {
    if (ws.readyState === 1) ws.send(JSON.stringify(msg))
  }

  manager.setBroadcast(broadcast)

  wss.on('connection', (ws) => {
    log('Client connected')
    sendTo(ws, { type: 'auth_required' })

    ws.on('message', (raw) => {
      let msg
      try { msg = JSON.parse(raw) } catch { return }

      if (msg.type === 'auth') {
        if (msg.token === token) {
          authenticated.add(ws)
          sendTo(ws, { type: 'auth_result', success: true })
          sendTo(ws, { type: 'default_working_directory', path: process.env.HOME })
          sendTo(ws, { type: 'whisper_ready', ready: false })
          sendTo(ws, { type: 'kokoro_ready', ready: false })
          log('Client authenticated')
        } else {
          sendTo(ws, { type: 'auth_result', success: false, message: 'Invalid token' })
          log('Auth failed')
        }
        return
      }

      if (!authenticated.has(ws)) {
        sendTo(ws, { type: 'error', message: 'Not authenticated' })
        return
      }

      handleMessage(msg, ws, { manager, broadcast, sendTo })
    })

    ws.on('close', () => {
      authenticated.delete(ws)
      log('Client disconnected')
    })
  })

  log(`Cloude Agent listening on port ${port}`)
}
