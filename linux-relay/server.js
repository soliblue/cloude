import { WebSocketServer } from "ws"
import { log } from "./log.js"
import { handleMessage } from "./handlers.js"
import { cleanupTerminal } from "./handlers-terminal.js"
import { RunnerManager } from "./runner.js"
import { loadSkills } from "./skills.js"
import { DEFAULT_PROJECT } from "./shared.js"

export function createServer(port, token, dataDir) {
  const wss = new WebSocketServer({ port })
  const authenticated = new Set()
  const manager = new RunnerManager()
  let connectionCount = 0

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

  wss.on("connection", (ws, req) => {
    connectionCount++
    const ip = req.socket.remoteAddress
    log(`Client connected (#${connectionCount} from ${ip})`)
    sendTo(ws, { type: "auth_required" })

    ws.on("message", (raw) => {
      let msg
      try { msg = JSON.parse(raw) } catch (e) {
        log(`Failed to parse message: ${e.message} (raw length=${raw.length})`)
        return
      }

      if (msg.type === "auth") {
        if (msg.token === token) {
          authenticated.add(ws)
          sendTo(ws, { type: "auth_result", success: true })
          sendTo(ws, { type: "default_working_directory", path: DEFAULT_PROJECT })
          sendTo(ws, { type: "whisper_ready", ready: true })
          const skills = loadSkills(DEFAULT_PROJECT)
          if (skills.length) sendTo(ws, { type: "skills", skills })
          log(`Client authenticated (${ip})`)
        } else {
          sendTo(ws, { type: "auth_result", success: false, message: "Invalid token" })
          log(`Auth failed (${ip})`)
        }
        return
      }

      if (!authenticated.has(ws)) {
        sendTo(ws, { type: "error", message: "Not authenticated" })
        log(`Unauthenticated message: ${msg.type} (${ip})`)
        return
      }

      log(`<- ${msg.type}${msg.conversationId ? ` (conv=${msg.conversationId.slice(0, 8)})` : ""}`)

      try {
        handleMessage(msg, ws, { manager, broadcast, sendTo })
      } catch (e) {
        log(`Handler error for ${msg.type}: ${e.message}`)
        sendTo(ws, { type: "error", message: `Handler error: ${e.message}` })
      }
    })

    ws.on("error", (err) => {
      log(`WebSocket error (${ip}): ${err.message}`)
    })

    ws.on("close", (code, reason) => {
      cleanupTerminal(ws)
      authenticated.delete(ws)
      log(`Client disconnected (${ip}, code=${code}, reason=${reason || "none"})`)
    })
  })

  wss.on("error", (err) => {
    log(`Server error: ${err.message}`)
  })

  setInterval(() => {
    const clients = wss.clients.size
    const authed = authenticated.size
    const procs = manager.getProcessInfo().length
    log(`[health] clients=${clients} authed=${authed} procs=${procs} uptime=${Math.floor(process.uptime())}s mem=${Math.round(process.memoryUsage().rss / 1024 / 1024)}MB`)
  }, 3600000)

  log(`Cloude Agent listening on port ${port}`)
}
