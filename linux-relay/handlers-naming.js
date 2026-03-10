import { spawn } from 'child_process'
import { log } from './log.js'

const AVAILABLE_SYMBOLS = [
  "message", "message.fill", "bubble.left", "bubble.left.fill", "bubble.right", "bubble.right.fill", "phone", "phone.fill", "video", "video.fill", "envelope", "envelope.fill", "paperplane", "paperplane.fill", "bell", "bell.fill", "megaphone", "megaphone.fill",
  "sun.max", "sun.max.fill", "moon", "moon.fill", "moon.stars", "cloud", "cloud.fill", "cloud.bolt", "cloud.rain", "snowflake", "thermometer.sun",
  "pencil", "pencil.circle.fill", "folder", "folder.fill", "paperclip", "link", "book", "book.fill", "bookmark", "bookmark.fill", "tag", "tag.fill", "camera", "camera.fill", "photo", "photo.fill", "music.note", "headphones", "lightbulb", "lightbulb.fill", "cpu", "memorychip", "keyboard", "printer", "tv", "display",
  "iphone", "laptopcomputer", "desktopcomputer", "server.rack", "externaldrive", "gamecontroller", "gamecontroller.fill",
  "wifi", "antenna.radiowaves.left.and.right", "network", "globe", "globe.americas", "globe.europe.africa", "airplane", "car", "car.fill", "bicycle", "location", "location.fill", "map", "map.fill", "mappin",
  "leaf", "leaf.fill", "tree", "tree.fill", "mountain.2", "flame", "flame.fill", "drop", "drop.fill", "bolt", "bolt.fill", "sparkles", "star", "star.fill", "sun.horizon",
  "heart", "heart.fill", "heart.circle", "bolt.heart", "cross", "cross.fill", "pills", "brain.head.profile", "figure.walk", "figure.run", "dumbbell", "sportscourt",
  "cart", "cart.fill", "bag", "bag.fill", "creditcard", "creditcard.fill", "dollarsign.circle", "building.columns", "storefront", "basket", "barcode", "qrcode",
  "clock", "clock.fill", "alarm", "stopwatch", "timer", "hourglass", "calendar", "calendar.circle",
  "play", "play.fill", "play.circle", "pause", "pause.fill", "stop", "stop.fill", "shuffle", "repeat", "speaker", "speaker.wave.3", "music.mic", "guitars", "pianokeys", "theatermasks", "ticket",
  "trash", "trash.fill", "doc", "doc.fill", "doc.text", "clipboard", "clipboard.fill", "list.bullet", "list.number", "checklist",
  "arrow.up", "arrow.down", "arrow.clockwise", "arrow.counterclockwise", "arrow.triangle.2.circlepath", "arrow.up.arrow.down",
  "circle", "circle.fill", "square", "square.fill", "triangle", "triangle.fill", "diamond", "diamond.fill", "hexagon", "hexagon.fill", "shield", "shield.fill",
  "plus", "minus", "multiply", "number", "percent", "function", "chevron.left.forwardslash.chevron.right",
  "lock", "lock.fill", "key", "key.fill", "eye", "eye.fill", "eye.slash", "hand.raised", "hand.thumbsup", "exclamationmark.shield", "checkmark.shield",
  "terminal", "terminal.fill", "apple.terminal", "hammer", "hammer.fill", "wrench", "wrench.fill", "wrench.and.screwdriver", "gearshape", "gearshape.fill", "gearshape.2", "ant", "ant.fill", "ladybug",
  "checkmark", "checkmark.circle", "checkmark.circle.fill", "xmark", "xmark.circle", "exclamationmark.triangle", "info.circle", "questionmark.circle", "plus.circle", "minus.circle", "flag", "flag.fill", "bell.badge"
]

export function handleSuggestName(text, context, conversationId, ws, sendTo) {
  if (!text || !conversationId) return

  let contextBlock = ''
  if (context && context.length) {
    contextBlock = '\nConversation so far:\n' + context.map(c => `- ${c.slice(0, 300)}`).join('\n') + '\n'
  }

  const symbolList = AVAILABLE_SYMBOLS.join(', ')
  const prompt = `You are naming a chat window in a mobile app. The user needs to glance at the name and instantly know what this conversation is about.
${contextBlock}
Latest user message: "${text}"

Suggest a short conversation name (1-3 words) that describes what's being worked on or discussed. Be specific and descriptive, not generic or catchy. Good examples: "Auth Bug Fix", "Dark Mode", "Rename Logic", "Memory System". Bad examples: "Spark", "New Chat", "Quick Fix".

Also pick an SF Symbol icon from this list that best fits the topic:
${symbolList}

Respond with ONLY a JSON object like: {"name": "Short Name", "symbol": "star"}
You MUST pick a symbol from the list above. Pick something specific and creative, not generic.
Prefer outline versions of icons (e.g. "star" over "star.fill") unless only a .fill variant exists.`

  const escaped = prompt.replace(/'/g, "'\\''")
  const command = `claude --model sonnet -p '${escaped}' --max-turns 1 --output-format text`

  log(`Name suggestion request for ${conversationId.slice(0, 8)}`)

  const { CLAUDECODE, ...cleanEnv } = process.env
  const env = { ...cleanEnv, NO_COLOR: '1', PATH: cleanEnv.PATH || '/usr/local/bin:/usr/bin:/bin' }
  const proc = spawn('bash', ['-c', command], { env, stdio: ['ignore', 'pipe', 'pipe'] })
  let stdout = ''
  let stderr = ''

  const timeout = setTimeout(() => {
    proc.kill('SIGTERM')
    log(`Name suggestion timed out. stderr: ${stderr.trim().slice(0, 200)}`)
  }, 15000)

  proc.stdout.on('data', d => { stdout += d })
  proc.stderr.on('data', d => { stderr += d })

  proc.on('close', code => {
    clearTimeout(timeout)
    if (stderr.trim()) log(`Name suggestion stderr: ${stderr.trim().slice(0, 200)}`)
    if (code !== 0) log(`Name suggestion exited with code ${code}`)
    const output = stdout.trim()
    if (!output) return

    let jsonStr = output
    const start = jsonStr.indexOf('{')
    const end = jsonStr.lastIndexOf('}')
    if (start !== -1 && end !== -1) jsonStr = jsonStr.slice(start, end + 1)

    try {
      const result = JSON.parse(jsonStr)
      if (result.name) {
        log(`Name suggestion: "${result.name}" symbol=${result.symbol || 'nil'}`)
        sendTo(ws, { type: 'name_suggestion', name: result.name, symbol: result.symbol || null, conversationId })
      }
    } catch {
      log(`Name suggestion parse failed: ${output.slice(0, 100)}`)
    }
  })

  proc.on('error', err => {
    clearTimeout(timeout)
    log(`Name suggestion error: ${err.message}`)
  })
}
