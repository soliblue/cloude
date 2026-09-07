export default class SubscriptionPolicy {
  static codex(account, config, limits, { capacity = true } = {}) {
    if (account.account?.type !== 'chatgpt') {
      throw new Error('Sign in to Codex with your ChatGPT subscription on this endpoint using codex login. API key billing is not supported.')
    }
    if (Object.keys(config.config?.model_providers?.openai || {}).length > 0) {
      throw new Error('Subscription-only mode requires the built-in OpenAI provider. Remove custom model_providers.openai overrides before continuing.')
    }
    for (const [key, host, prefix] of [['chatgpt_base_url', 'chatgpt.com', '/backend-api'], ['openai_base_url', 'api.openai.com', '/v1']]) {
      if (config.config?.[key]) {
        const url = new URL(config.config[key])
        if (url.protocol !== 'https:' || url.hostname !== host || url.port || url.username || url.password || url.search || ![prefix, `${prefix}/`, `${prefix}/codex`].includes(url.pathname)) {
          throw new Error('Subscription-only mode does not allow custom inference endpoints.')
        }
      }
    }
    if (!capacity) { return }
    const quota = limits.rateLimitsByLimitId?.codex || limits.rateLimits
    const windows = [quota?.primary, quota?.secondary].filter((window) => window != null)
    if (!windows.length || windows.some((window) => !Number.isFinite(window.usedPercent) || window.usedPercent < 0)) {
      throw new Error('Cannot verify Codex subscription capacity. Check the endpoint account and retry.')
    }
    if (windows.some((window) => window.usedPercent >= 100)) {
      throw new Error('Codex subscription usage limit reached. Wait for its reset; paid credits are not used by this app.')
    }
  }

  static claudeSettings(settings) {
    if (!settings || typeof settings !== 'object' || Array.isArray(settings)) {
      throw new Error('Claude settings could not be verified for subscription-only mode.')
    }
    if (settings.apiKeyHelper || settings.policyHelper || (settings.forceLoginMethod && settings.forceLoginMethod !== 'claudeai')
      || ['ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_BASE_URL', 'ANTHROPIC_PROFILE'].some(key => settings.env?.[key] != null && String(settings.env[key]) !== '')
      || ['CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY'].some(key => settings.env?.[key] != null && !['', '0', 'false'].includes(String(settings.env[key]).toLowerCase()))) {
      throw new Error('Claude settings contain an API credential or paid-provider override. Remove that override to use subscription-only mode.')
    }
  }

  static claude(account) {
    if (!account.loggedIn || account.authMethod !== 'claude.ai' || account.apiProvider !== 'firstParty' || account.apiKeySource || !account.subscriptionType) {
      throw new Error('Sign in to Claude Code with your Claude subscription. API keys, credential helpers and cloud-provider billing are not supported.')
    }
  }
}
