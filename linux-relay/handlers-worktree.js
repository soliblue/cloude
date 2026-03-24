import { execSync } from 'child_process'
import { sendError } from './shared.js'

export function handleAttachBranch(repoPath, branch, conversationId, ws, sendTo) {
  const sanitized = branch.replace(/\//g, '--')
  const worktreePath = `${repoPath}/.cloude-worktrees/${sanitized}`

  try {
    try {
      execSync(`test -d "${worktreePath}"`)
    } catch {
      try {
        execSync(`git worktree add "${worktreePath}" "${branch}"`, { cwd: repoPath })
      } catch {
        execSync(`git worktree add "${worktreePath}" -b "${branch}" "origin/${branch}"`, { cwd: repoPath })
      }
    }
    sendTo(ws, { type: 'branch_attached', branch, worktreePath, conversationId })
  } catch (e) {
    sendError(ws, sendTo, e)
  }
}

export function handleListBranches(repoPath, ws, sendTo) {
  try {
    const local = execSync("git branch --format='%(refname:short)'", { cwd: repoPath, encoding: 'utf8' })
      .trim().split('\n').filter(Boolean)
    const current = execSync('git rev-parse --abbrev-ref HEAD', { cwd: repoPath, encoding: 'utf8' }).trim()
    sendTo(ws, { type: 'branch_list', branches: local, current })
  } catch (e) {
    sendError(ws, sendTo, e)
  }
}
