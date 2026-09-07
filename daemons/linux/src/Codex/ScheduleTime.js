const formatters = new Map()

function components(time, timeZone) {
  if (!formatters.has(timeZone)) { formatters.set(timeZone, new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' })) }
  return Object.fromEntries(formatters.get(timeZone).formatToParts(time).filter(part => part.type !== 'literal').map(part => [part.type, Number(part.value)]))
}

export function validSchedule(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) { return false }
  if (value.kind === 'interval') { return Object.keys(value).every(key => ['kind', 'minutes'].includes(key)) && Number.isInteger(value.minutes) && value.minutes >= 15 && value.minutes <= 10080 }
  if (value.kind !== 'calendar' || !Object.keys(value).every(key => ['kind', 'time', 'timeZone', 'daysOfWeek'].includes(key)) || typeof value.time !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value.time) || typeof value.timeZone !== 'string' || value.timeZone.length > 100 || !Array.isArray(value.daysOfWeek) || !value.daysOfWeek.length || value.daysOfWeek.length > 7 || new Set(value.daysOfWeek).size !== value.daysOfWeek.length || !value.daysOfWeek.every(day => Number.isInteger(day) && day >= 1 && day <= 7)) { return false }
  try { components(0, value.timeZone); return true } catch { return false }
}

export function nextOccurrence(schedule, after, anchorAt = after) {
  if (schedule.kind === 'interval') { return anchorAt + Math.max(0, Math.floor((after - anchorAt) / (schedule.minutes * 60000)) + 1) * schedule.minutes * 60000 }
  const local = components(after, schedule.timeZone)
  const [hour, minute] = schedule.time.split(':').map(Number)
  for (let day = 0; day <= 14; day++) {
    const date = new Date(Date.UTC(local.year, local.month - 1, local.day + day))
    if (!schedule.daysOfWeek.includes(date.getUTCDay() || 7)) { continue }
    const wall = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), hour, minute)
    const candidates = new Set()
    for (const hours of [-36, -12, 0, 12, 36]) {
      const sample = wall + hours * 3600000
      const parts = components(sample, schedule.timeZone)
      const offset = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second) - sample
      const candidate = wall - offset
      const actual = components(candidate, schedule.timeZone)
      if (actual.year === date.getUTCFullYear() && actual.month === date.getUTCMonth() + 1 && actual.day === date.getUTCDate() && actual.hour === hour && actual.minute === minute) { candidates.add(candidate) }
    }
    const first = Math.min(...candidates)
    if (Number.isFinite(first) && first > after) { return first }
  }
  throw new Error('Cannot calculate the next scheduled time.')
}
