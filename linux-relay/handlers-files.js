import { readdirSync, readFileSync, statSync } from 'fs'
import { join, extname } from 'path'
import { execSync } from 'child_process'
import { MIME_TYPES, MAX_CHUNK, toAppleTimestamp, sendError } from './shared.js'

export function handleListDirectory(dirPath, ws, sendTo) {
  const resolved = dirPath === '~' || !dirPath ? process.env.HOME : dirPath.replace(/^~/, process.env.HOME)
  try {
    const items = readdirSync(resolved, { withFileTypes: true })
    const entries = items.map(d => {
      const fullPath = join(resolved, d.name)
      try {
        const st = statSync(fullPath)
        return {
          name: d.name,
          path: fullPath,
          isDirectory: d.isDirectory(),
          size: st.size,
          modified: toAppleTimestamp(st.mtime.getTime()),
          mimeType: d.isDirectory() ? null : (MIME_TYPES[extname(d.name)] || 'application/octet-stream')
        }
      } catch {
        return { name: d.name, path: fullPath, isDirectory: d.isDirectory(), size: 0, modified: toAppleTimestamp(Date.now()), mimeType: null }
      }
    })
    entries.sort((a, b) => {
      if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1
      return a.name.localeCompare(b.name)
    })
    sendTo(ws, { type: 'directory_listing', path: resolved, entries })
  } catch (e) {
    sendError(ws, sendTo, e)
  }
}

export function handleGetFile(filePath, ws, sendTo) {
  try {
    const st = statSync(filePath)
    if (st.isDirectory()) return handleListDirectory(filePath, ws, sendTo)

    const data = readFileSync(filePath)
    const mimeType = MIME_TYPES[extname(filePath)] || 'application/octet-stream'
    const b64 = data.toString('base64')

    if (b64.length > MAX_CHUNK) {
      const totalChunks = Math.ceil(b64.length / MAX_CHUNK)
      for (let i = 0; i < totalChunks; i++) {
        sendTo(ws, {
          type: 'file_chunk',
          path: filePath,
          chunkIndex: i,
          totalChunks,
          data: b64.slice(i * MAX_CHUNK, (i + 1) * MAX_CHUNK),
          mimeType,
          size: st.size
        })
      }
    } else {
      sendTo(ws, { type: 'file_content', path: filePath, data: b64, mimeType, size: st.size, truncated: false })
    }
  } catch (e) {
    sendError(ws, sendTo, e)
  }
}

export function handleSearchFiles(query, workingDirectory, ws, sendTo) {
  try {
    const findFlag = query.includes('/') ? '-path' : '-name'
    const pattern = query.includes('/') ? `*${query}*` : `*${query}*`
    const output = execSync(`find '${workingDirectory}' -maxdepth 5 ${findFlag} '${pattern}' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -50`, { encoding: 'utf8' })
    const files = output.split('\n').filter(Boolean)
    sendTo(ws, { type: 'file_search_results', files })
  } catch {
    sendTo(ws, { type: 'file_search_results', files: [] })
  }
}
