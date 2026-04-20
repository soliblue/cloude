#!/usr/bin/env node
import { WebSocketServer } from 'ws'

const PORT = parseInt(process.env.CLOUDE_PORT || '8765')

const wss = new WebSocketServer({ port: PORT })
wss.on('connection', (socket) => {
  socket.send(JSON.stringify({ type: 'hello' }))
})

console.log(`Daemon for Remote CC listening on :${PORT}`)
