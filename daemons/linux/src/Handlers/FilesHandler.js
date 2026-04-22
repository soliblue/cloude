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

function parsedRange(rangeHeader) {
  const match = /^bytes=(\d+)-(\d*)$/u.exec(rangeHeader)
  if (match) {
    return {
      start: Number.parseInt(match[1], 10),
      end: match[2] ? Number.parseInt(match[2], 10) : null
    }
  }
  return null
}

export function list(request) {
  if (request.query.path) {
    const directory = resolved(request.query.path)
    if (fs.existsSync(directory) && fs.statSync(directory).isDirectory()) {
      return HTTPResponse.json(200, {
        path: directory,
        entries: fs
          .readdirSync(directory, { withFileTypes: true })
          .filter((item) => !item.name.startsWith('.'))
          .map((item) => entry(path.join(directory, item.name), fs.statSync(path.join(directory, item.name))))
          .sort((left, right) => {
            if (left.isDirectory !== right.isDirectory) {
              return left.isDirectory ? -1 : 1
            }
            return left.name.localeCompare(right.name)
          })
      })
    }
    return HTTPResponse.json(404, { error: 'not_found' })
  }
  return HTTPResponse.json(400, { error: 'missing_path' })
}

export function read(request) {
  if (request.query.path) {
    const file = resolved(request.query.path)
    if (fs.existsSync(file) && fs.statSync(file).isFile()) {
      if (request.headers.range) {
        const range = parsedRange(request.headers.range)
        const size = fs.statSync(file).size
        if (range && range.start <= size - 1) {
          const end = Math.min(range.end ?? size - 1, size - 1)
          const buffer = Buffer.alloc(end - range.start + 1)
          const handle = fs.openSync(file, 'r')
          fs.readSync(handle, buffer, 0, buffer.length, range.start)
          fs.closeSync(handle)
          return new HTTPResponse(206, buffer, mimeType(file), {
            'Accept-Ranges': 'bytes',
            'Content-Range': `bytes ${range.start}-${end}/${size}`
          })
        }
        return HTTPResponse.json(400, { error: 'bad_range' })
      }
      return new HTTPResponse(200, fs.readFileSync(file), mimeType(file))
    }
    return HTTPResponse.json(404, { error: 'not_found' })
  }
  return HTTPResponse.json(400, { error: 'missing_path' })
}

export function search(request) {
  if (request.query.path && request.query.query) {
    const root = resolved(request.query.path)
    const needle = request.query.query.toLowerCase()
    if (fs.existsSync(root) && fs.statSync(root).isDirectory()) {
      const hits = []
      const stack = [{ directory: root, depth: 0 }]
      while (stack.length > 0 && hits.length < 100) {
        const { directory, depth } = stack.pop()
        for (const item of fs.readdirSync(directory, { withFileTypes: true })) {
          if (item.name.startsWith('.')) {
            continue
          }
          if (item.name === '.git' || item.name === 'node_modules') {
            continue
          }
          const fullPath = path.join(directory, item.name)
          const stats = fs.statSync(fullPath)
          if (item.name.toLowerCase().includes(needle)) {
            hits.push(entry(fullPath, stats))
            if (hits.length >= 100) {
              break
            }
          }
          if (item.isDirectory() && depth < 5) {
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
