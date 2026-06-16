import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'

const root = new URL('..', import.meta.url).pathname
const src = join(root, 'src')
const failures = []

function swiftFiles(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name)
    const stat = statSync(path)
    if (stat.isDirectory()) return swiftFiles(path)
    return path.endsWith('.swift') ? [path] : []
  })
}

function fail(path, message) {
  failures.push(`${relative(root, path)}: ${message}`)
}

for (const path of swiftFiles(src)) {
  const text = readFileSync(path, 'utf8')
  const rel = relative(root, path)
  if (/Features\/[^/]+\/Logic\//.test(rel) && text.includes('import SwiftUI')) {
    fail(path, 'Logic files must not import SwiftUI')
  }
  if (text.includes('@StateObject')) fail(path, 'Use @State with @Observable instead of @StateObject')
  if (text.includes('ObservableObject')) fail(path, 'Use Observation instead of ObservableObject')
  if (text.includes('@EnvironmentObject')) fail(path, 'Avoid broad EnvironmentObject observation')
  if (text.includes('AnyView')) fail(path, 'Avoid AnyView type erasure')
  if (text.includes('.sheet(isPresented:')) fail(path, 'Use item-driven sheet routing instead of boolean sheet state')
  if (/allCases,\s*id:\s*\\\.self/.test(text)) fail(path, 'Make option enums Identifiable instead of using id: \\.self')
  if (/[\u2013\u2014]/.test(text)) fail(path, 'Use ASCII punctuation')
  for (const line of text.split('\n')) {
    if (/^\s*\/\//.test(line) || /^\s*\/\*/.test(line) || /^\s*\*/.test(line) || /\*\/\s*$/.test(line)) {
      fail(path, 'Swift source should not include comments')
    }
    if (line.includes('Task.detached') && !line.includes('@concurrent')) {
      fail(path, 'Task.detached closures must be explicit @concurrent')
    }
  }
  if (/Features\/[^/]+\/UI\//.test(rel) && text.split('\n').length > 300) {
    fail(path, 'SwiftUI view files should stay below 300 lines')
  }
}

if (failures.length > 0) {
  console.error(failures.join('\n'))
  process.exit(1)
}

console.log('iOS guideline audit passed')
