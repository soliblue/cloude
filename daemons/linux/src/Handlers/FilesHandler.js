import fs from 'node:fs'
import path from 'node:path'
import HTTPResponse from '../Networking/HTTPResponse.js'

const mimeTypes = {
  '.aac': 'audio/aac',
  '.csv': 'text/csv',
  '.gif': 'image/gif',
  '.html': 'text/html',
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.json': 'application/json',
  '.m4a': 'audio/mp4',
  '.md': 'text/markdown',
  '.mov': 'video/quicktime',
  '.mp3': 'audio/mpeg',
  '.mp4': 'video/mp4',
  '.pdf': 'application/pdf',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.swift': 'text/x-swift',
  '.txt': 'text/plain',
  '.wav': 'audio/wav',
  '.webm': 'video/webm',
  '.webp': 'image/webp',
  '.xml': 'text/xml',
  '.yaml': 'text/yaml',
  '.yml': 'text/yaml'
}

function resolved(filePath) {
  return filePath.startsWith('~/')
    ? path.join(process.env.HOME || '', filePath.slice(2))
    : filePath === '~'
      ? process.env.HOME || ''
      : path.resolve(filePath)
}

function mimeType(filePath) {
  return mimeTypes[path.extname(filePath).toLowerCase()] || 'application/octet-stream'
}

function entry(filePath, stats) {
  const isDirectory = stats.isDirectory()
  const result = {
    name: path.basename(filePath),
    path: filePath,
    isDirectory
  }
  if (typeof stats.size === 'number') {
    result.size = stats.size
  }
  result.modifiedAt = new Date(stats.mtimeMs).toISOString()
  if (!isDirectory) {
    result.mimeType = mimeType(filePath)
  }
  return result
}

function parsedRange(header, size) {
  const match = /^bytes=(\d*)-(\d*)$/u.exec(header)
  if (match && (match[1] || match[2]) && size > 0) {
    const start = match[1] ? Number(match[1]) : Math.max(0, size - Number(match[2]))
    const end = match[1] && match[2] ? Math.min(Number(match[2]), size - 1) : size - 1
    if (Number.isSafeInteger(start) && Number.isSafeInteger(end) && start <= end && start < size && (match[1] || Number(match[2]) > 0)) {
      return { start, end }
    }
  }
  return null
}

export async function list(request) {
  if (request.query.path) {
    const directory = resolved(request.query.path)
    const showHidden = request.query.showHidden === 'true'
    if ((await fs.promises.stat(directory).catch(() => null))?.isDirectory()) {
      const entries = []
      for (const item of await fs.promises.readdir(directory, { withFileTypes: true })) {
        if (showHidden || !item.name.startsWith('.')) {
          const fullPath = path.join(directory, item.name)
          const stats = await fs.promises.stat(fullPath).catch(() => null)
          if (stats) { entries.push(entry(fullPath, stats)) }
        }
      }
      entries.sort((left, right) => left.isDirectory !== right.isDirectory
        ? left.isDirectory ? -1 : 1 : left.name.localeCompare(right.name))
      return HTTPResponse.json(200, { path: directory, entries })
    }
    return HTTPResponse.json(404, { error: 'not_found' })
  }
  return HTTPResponse.json(400, { error: 'missing_path' })
}

export function read(request) {
  if (request.query.path) {
    const file = resolved(request.query.path)
    const stats = fs.statSync(file, { throwIfNoEntry: false })
    if (stats?.isFile()) {
      const range = request.headers.range ? parsedRange(request.headers.range, stats.size) : null
      if (request.headers.range && !range) {
        return new HTTPResponse(416, Buffer.alloc(0), mimeType(file), {
          'Content-Range': `bytes */${stats.size}`, 'Accept-Ranges': 'bytes'
        })
      }
      return HTTPResponse.stream(range ? 206 : 200, mimeType(file), {
        'Accept-Ranges': 'bytes',
        'Content-Length': String(range ? range.end - range.start + 1 : stats.size),
        'Last-Modified': stats.mtime.toUTCString(),
        ...(range ? { 'Content-Range': `bytes ${range.start}-${range.end}/${stats.size}` } : {})
      }, (response) => {
        const stream = fs.createReadStream(file, range || {})
        response.once('close', () => stream.destroy())
        stream.once('error', () => response.destroy())
        stream.pipe(response)
      })
    }
    return HTTPResponse.json(404, { error: 'not_found' })
  }
  return HTTPResponse.json(400, { error: 'missing_path' })
}

export async function search(request) {
  if (request.query.path && request.query.query) {
    const root = resolved(request.query.path)
    const needle = request.query.query.toLowerCase()
    if ((await fs.promises.stat(root).catch(() => null))?.isDirectory()) {
      const hits = []
      const stack = [{ directory: root, depth: 0 }]
      while (stack.length > 0 && hits.length < 100) {
        const { directory, depth } = stack.pop()
        const items = await fs.promises.readdir(directory, { withFileTypes: true }).catch(() => [])
        for (const item of items) {
          if (item.name.startsWith('.')) {
            continue
          }
          if (item.name === '.git' || item.name === 'node_modules') {
            continue
          }
          const fullPath = path.join(directory, item.name)
          if (item.name.toLowerCase().includes(needle)) {
            const stats = await fs.promises.stat(fullPath).catch(() => null)
            if (stats) {
              hits.push(entry(fullPath, stats))
            }
            if (hits.length >= 100) {
              break
            }
          }
          if (item.isDirectory() && depth < 4) {
            stack.push({ directory: fullPath, depth: depth + 1 })
          }
        }
      }
      return HTTPResponse.json(200, { entries: hits })
    }
    return HTTPResponse.json(200, { entries: [] })
  }
  return HTTPResponse.json(400, { error: 'missing_params' })
}
