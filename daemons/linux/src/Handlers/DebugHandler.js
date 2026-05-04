import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import HTTPResponse from '../Networking/HTTPResponse.js'

const dataDirectory = process.env.CLOUDE_DATA || path.join(os.homedir(), '.cloude-agent')
const destinationPath = path.join(dataDirectory, 'ios-logs', 'latest.log')

function parsedBody(request) {
  try {
    return JSON.parse(request.body.toString('utf8'))
  } catch {
    return null
  }
}

export function uploadIOSLog(request) {
  const object = parsedBody(request)
  if (object && typeof object.content === 'string') {
    fs.mkdirSync(path.dirname(destinationPath), { recursive: true })
    fs.writeFileSync(destinationPath, object.content)
    return HTTPResponse.json(200, { ok: true, path: destinationPath })
  }
  return HTTPResponse.json(400, { error: 'bad_request' })
}
