export function split(rawPath) {
  const question = rawPath.indexOf('?')
  if (question === -1) {
    return { path: rawPath, query: {} }
  }
  return {
    path: rawPath.slice(0, question),
    query: Object.fromEntries(new URLSearchParams(rawPath.slice(question + 1)))
  }
}

export function match(path, pattern) {
  const pathParts = path.split('/').filter(Boolean)
  const patternParts = pattern.split('/').filter(Boolean)
  if (pathParts.length !== patternParts.length) {
    return null
  }
  const params = {}
  for (let index = 0; index < pathParts.length; index += 1) {
    if (patternParts[index].startsWith(':')) {
      params[patternParts[index].slice(1)] = pathParts[index]
    } else if (pathParts[index] !== patternParts[index]) {
      return null
    }
  }
  return params
}
