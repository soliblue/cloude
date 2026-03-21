import { execSync } from 'child_process'
import { sendError } from './shared.js'

export function handleGitStatus(path, ws, sendTo) {
  try {
    const branch = execSync('git rev-parse --abbrev-ref HEAD', { cwd: path, encoding: 'utf8' }).trim()
    let ahead = 0, behind = 0
    try {
      const counts = execSync('git rev-list --left-right --count HEAD...@{upstream}', { cwd: path, encoding: 'utf8' }).trim().split('\t')
      ahead = parseInt(counts[0]) || 0
      behind = parseInt(counts[1]) || 0
    } catch {}
    const statusOutput = execSync('git status --porcelain', { cwd: path, encoding: 'utf8' })
    const files = []
    for (const line of statusOutput.split('\n').filter(Boolean)) {
      const x = line[0], y = line[1]
      const filePath = line.slice(3)
      if (x === '?') {
        files.push({ status: '??', path: filePath, staged: false })
        continue
      }
      if (x !== ' ' && x !== '!') files.push({ status: x, path: filePath, staged: true })
      if (y !== ' ' && y !== '!') files.push({ status: y, path: filePath, staged: false })
    }
    const parseNumstat = (output) => {
      const stats = {}
      for (const line of output.split('\n').filter(Boolean)) {
        const [add, del, file] = line.split('\t')
        if (file && add !== '-') stats[file] = { additions: parseInt(add) || 0, deletions: parseInt(del) || 0 }
      }
      return stats
    }
    let unstagedStats = {}, stagedStats = {}
    try { unstagedStats = parseNumstat(execSync('git diff --numstat', { cwd: path, encoding: 'utf8' })) } catch {}
    try { stagedStats = parseNumstat(execSync('git diff --cached --numstat', { cwd: path, encoding: 'utf8' })) } catch {}
    for (const f of files) {
      const stats = f.staged ? stagedStats : unstagedStats
      if (stats[f.path]) { f.additions = stats[f.path].additions; f.deletions = stats[f.path].deletions }
    }
    sendTo(ws, { type: 'git_status_result', status: { branch, ahead, behind, files } })
  } catch (e) {
    sendError(ws, sendTo, e)
  }
}

export function handleGitDiff(path, file, staged, ws, sendTo) {
  try {
    const args = ['git', 'diff']
    if (staged) args.push('--cached')
    if (file) args.push('--', file)
    const cmd = args.join(' ')
    const diff = execSync(cmd, { cwd: path, encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 })
    sendTo(ws, { type: 'git_diff_result', path: file || path, diff })
  } catch (e) {
    sendError(ws, sendTo, e)
  }
}

export function handleGitCommit(path, message, files, ws, sendTo) {
  try {
    for (const f of files) execSync(`git add '${f}'`, { cwd: path })
    const output = execSync(`git commit -m '${message.replace(/'/g, "'\\''")}'`, { cwd: path, encoding: 'utf8' })
    sendTo(ws, { type: 'git_commit_result', success: true, message: output })
  } catch (e) {
    sendTo(ws, { type: 'git_commit_result', success: false, message: e.message })
  }
}
