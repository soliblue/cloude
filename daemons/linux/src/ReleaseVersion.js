export function isReleaseVersion(value) {
  return typeof value === 'string' && /^[0-9]{1,6}(?:\.[0-9]{1,6}){2,3}$/u.test(value)
}
