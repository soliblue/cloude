export default class CodexLogin {
  constructor(client) {
    this.client = client
    this.attempt = { state: { status: 'idle' }, early: new Map() }
    this.starting = null
    this.canceling = null
    client.on('notification', ({ method, params }) => {
      if (method === 'account/login/completed' && this.attempt.state.status === 'pending' && typeof params?.loginId === 'string' && typeof params.success === 'boolean') {
        if (this.attempt.state.loginId === params.loginId && !params.success && this.attempt.canceling) {
          this.attempt.failedDuringCancel = true
        } else if (this.attempt.state.loginId === params.loginId) {
          this.attempt.state = { status: params.success ? 'completed' : 'failed', loginId: params.loginId, ...(params.success ? {} : { error: 'Sign-in failed. Start a new device code and try again.' }) }
        } else if (!this.attempt.state.loginId && this.attempt.early.size < 16) {
          this.attempt.early.set(params.loginId, params.success)
        }
      }
    })
    client.on('disconnected', () => {
      if (this.attempt.state.status === 'pending') {
        this.attempt.state = { status: 'failed', ...(this.attempt.state.loginId ? { loginId: this.attempt.state.loginId } : {}), error: 'Codex disconnected during sign-in. Start a new device code.' }
      }
    })
  }

  snapshot() {
    return { ...this.attempt.state }
  }

  start() {
    if (this.canceling) { return this.canceling }
    if (this.starting) { return this.starting }
    if (this.attempt.state.status === 'pending') { return Promise.resolve(this.snapshot()) }
    const attempt = { state: { status: 'pending' }, early: new Map() }
    this.attempt = attempt
    this.starting = this.client.request('account/login/start', { type: 'chatgptDeviceCode' }).then((result) => {
      if (this.attempt === attempt && attempt.state.status === 'pending') {
        if (result?.type === 'chatgptDeviceCode' && typeof result.loginId === 'string' && result.loginId.length > 0 && result.loginId.length <= 512 && typeof result.userCode === 'string' && result.userCode.length > 0 && result.userCode.length <= 256 && typeof result.verificationUrl === 'string' && result.verificationUrl.length <= 2048
          && /^https:\/\/auth\.openai\.com\/[^\s]*$/u.test(result.verificationUrl)) {
          attempt.state = attempt.early.has(result.loginId)
            ? { status: attempt.early.get(result.loginId) ? 'completed' : 'failed', loginId: result.loginId, ...(attempt.early.get(result.loginId) ? {} : { error: 'Sign-in failed. Start a new device code and try again.' }) }
            : { status: 'pending', loginId: result.loginId, userCode: result.userCode, verificationUrl: result.verificationUrl }
        } else {
          attempt.state = { status: 'failed', error: 'Codex did not return a supported ChatGPT device-code sign-in.' }
        }
      }
      return this.snapshot()
    }, () => {
      if (this.attempt === attempt && attempt.state.status === 'pending') { attempt.state = { status: 'failed', error: 'Could not start Codex sign-in. Check the host connection and device-code sign-in availability.' } }
      return this.snapshot()
    }).finally(() => { attempt.early.clear(); this.starting = null })
    return this.starting
  }

  cancel() {
    if (this.canceling) { return this.canceling }
    this.canceling = Promise.resolve(this.starting).then(async () => {
      const attempt = this.attempt
      if (attempt.state.status === 'pending' && attempt.state.loginId) {
        const loginId = attempt.state.loginId
        attempt.canceling = true
        await this.client.request('account/login/cancel', { loginId }).then((result) => {
          if (this.attempt === attempt && attempt.state.status === 'pending') {
            attempt.state = result?.status === 'canceled' || result?.status === 'notFound'
              ? { status: 'canceled', loginId }
              : attempt.failedDuringCancel ? { status: 'failed', loginId, error: 'Sign-in failed. Start a new device code and try again.' } : { ...attempt.state, error: 'Could not cancel sign-in. Try again.' }
          }
        }, () => {
          if (this.attempt === attempt && attempt.state.status === 'pending') { attempt.state = attempt.failedDuringCancel ? { status: 'failed', loginId, error: 'Sign-in failed. Start a new device code and try again.' } : { ...attempt.state, error: 'Could not cancel sign-in. Try again.' } }
        })
        attempt.canceling = false
      }
      return this.snapshot()
    }).finally(() => { this.canceling = null })
    return this.canceling
  }
}
