import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const mimeExtensions = {
  'image/gif': 'gif',
  'image/heic': 'heic',
  'image/heif': 'heif',
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/svg+xml': 'svg',
  'image/webp': 'webp'
}

export function preparePrompt(prompt, images) {
  if (!Array.isArray(images) || images.length === 0) {
    return prompt
  }
  const directory = path.join(os.tmpdir(), `cloude-images-${crypto.randomUUID()}`)
  fs.mkdirSync(directory, { recursive: true })
  const paths = []
  for (const [index, image] of images.entries()) {
    if (typeof image?.data === 'string') {
      const data = Buffer.from(image.data, 'base64')
      if (data.length > 0) {
        const extension = mimeExtensions[image.mediaType] || 'png'
        const file = path.join(directory, `image-${index}.${extension}`)
        fs.writeFileSync(file, data)
        paths.push(file)
      }
    }
  }
  if (paths.length === 0) {
    return prompt
  }
  return `${paths.map((file) => `Read the image at ${file}.`).join(' ')}\n\n${prompt}`
}
