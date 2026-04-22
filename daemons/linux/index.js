#!/usr/bin/env node
import HTTPServer from './src/Networking/HTTPServer.js'
import { daemonToken, daemonTokenPath } from './src/Routing/DaemonAuth.js'

const host = process.env.CLOUDE_HOST || '0.0.0.0'
const port = Number.parseInt(process.env.CLOUDE_PORT || '8765', 10)

daemonToken()
new HTTPServer({ host, port }).start()
console.log(`DaemonAuth: token loaded from ${daemonTokenPath()}`)
