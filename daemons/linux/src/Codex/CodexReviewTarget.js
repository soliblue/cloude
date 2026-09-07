export function validReviewTarget(target) {
  if (!target || typeof target !== 'object' || Array.isArray(target)) { return false }
  const allowed = { uncommittedChanges: ['type'], baseBranch: ['type', 'branch'], commit: ['type', 'sha', 'title'], custom: ['type', 'instructions'] }[target.type]
  if (!allowed || Object.keys(target).some((key) => !allowed.includes(key))) { return false }
  if (target.type === 'uncommittedChanges') { return true }
  if (target.type === 'baseBranch') {
    return typeof target.branch === 'string' && target.branch.length > 0 && target.branch.length <= 255
      && !/[\s\u0000-\u001f\u007f~^:?*\[\]\\]/u.test(target.branch) && !target.branch.startsWith('-') && !target.branch.startsWith('/') && !target.branch.endsWith('/')
      && !target.branch.includes('..') && !target.branch.includes('//') && !target.branch.includes('@{')
      && target.branch.split('/').every((part) => !part.startsWith('.') && !part.endsWith('.') && !part.endsWith('.lock'))
  }
  if (target.type === 'commit') {
    return typeof target.sha === 'string' && /^[a-f0-9]{4,64}$/iu.test(target.sha)
      && (target.title === undefined || target.title === null || typeof target.title === 'string' && target.title.length <= 500 && !target.title.includes('\0'))
  }
  return typeof target.instructions === 'string' && target.instructions.trim().length > 0 && target.instructions.length <= 16000 && !target.instructions.includes('\0')
}
