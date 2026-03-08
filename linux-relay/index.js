#!/usr/bin/env node
import { createServer } from './server.js'
import { generateToken, loadToken } from './auth.js'
import { log } from './log.js'

const PORT = parseInt(process.env.CLOUDE_PORT || '8765')
const DATA_DIR = process.env.CLOUDE_DATA || `${process.env.HOME}/.cloude-agent`

const token = loadToken(DATA_DIR) || generateToken(DATA_DIR)
log(`Auth token: ${token.slice(0, 8)}...`)
log(`Data dir: ${DATA_DIR}`)

createServer(PORT, token, DATA_DIR)
