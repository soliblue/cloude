import { appendFileSync, mkdirSync } from 'fs'
import { join } from 'path'

const DATA_DIR = process.env.CLOUDE_DATA || `${process.env.HOME}/.cloude-agent`
const LOG_DIR = join(DATA_DIR, 'logs')
mkdirSync(LOG_DIR, { recursive: true })

function ts() {
  return new Date().toISOString().replace('T', ' ').slice(0, 19)
}

export function log(msg) {
  const line = `[${ts()}] ${msg}`
  console.log(line)
  const file = join(LOG_DIR, `${new Date().toISOString().slice(0, 10)}.log`)
  appendFileSync(file, line + '\n')
}
