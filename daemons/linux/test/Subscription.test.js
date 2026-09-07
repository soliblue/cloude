import test from 'node:test'
import assert from 'node:assert/strict'
import SubscriptionPolicy from '../src/Runtime/SubscriptionPolicy.js'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { requireClaudeConfiguration, spawnEnvironment } from '../src/Runtime/ClaudeRuntime.js'

test('Codex refuses paid credential/provider overrides even with an active ChatGPT login', () => {
  const account = { account: { type: 'chatgpt' } }
  const limits = { rateLimits: { primary: { usedPercent: 15 } } }
  assert.doesNotThrow(() => SubscriptionPolicy.codex(account, { config: { chatgpt_base_url: 'https://chatgpt.com/backend-api/' } }, limits))
  assert.throws(() => SubscriptionPolicy.codex(account, { config: { model_providers: { openai: { experimental_bearer_token: 'test-key' } } } }, limits), /built-in OpenAI provider/)
  assert.throws(() => SubscriptionPolicy.codex(account, { config: { chatgpt_base_url: 'https://paid-gateway.example/backend-api' } }, limits), /custom inference endpoints/)
  assert.throws(() => SubscriptionPolicy.codex(account, { config: { openai_base_url: 'https://api.openai.com/v1?api_key=test' } }, limits), /custom inference endpoints/)
  assert.throws(() => SubscriptionPolicy.codex({ account: { type: 'apiKey' } }, { config: {} }, limits), /API key billing/)
})

test('Codex cannot start with exhausted or unverified subscription capacity', () => {
  const account = { account: { type: 'chatgpt' } }
  assert.throws(() => SubscriptionPolicy.codex(account, { config: {} }, { rateLimits: { primary: { usedPercent: 100 }, credits: { hasCredits: true } } }), /subscription usage limit/)
  assert.throws(() => SubscriptionPolicy.codex(account, { config: {} }, {}), /Cannot verify/)
  assert.doesNotThrow(() => SubscriptionPolicy.codex(account, { config: {} }, { rateLimitsByLimitId: { codex: { primary: { usedPercent: 20 } }, unrelated: { primary: { usedPercent: 100 } } } }))
})

test('Claude rejects API sources even when auth status also reports claude.ai', () => {
  const subscription = { loggedIn: true, authMethod: 'claude.ai', apiProvider: 'firstParty', subscriptionType: 'max' }
  assert.doesNotThrow(() => SubscriptionPolicy.claude(subscription))
  assert.throws(() => SubscriptionPolicy.claude({ ...subscription, apiKeySource: 'ANTHROPIC_API_KEY' }), /API keys/)
  assert.throws(() => SubscriptionPolicy.claude({ ...subscription, apiKeySource: 'apiKeyHelper', authMethod: 'api_key_helper' }), /API keys/)
  assert.throws(() => SubscriptionPolicy.claude({ ...subscription, apiProvider: 'bedrock' }), /cloud-provider/)
  assert.throws(() => SubscriptionPolicy.claude({ ...subscription, loggedIn: false }), /Sign in/)
})

test('agent subprocess environments do not inherit billing credentials or cloud-provider flags', (t) => {
  for (const key of ['ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'OPENAI_API_KEY', 'CLAUDE_CODE_USE_BEDROCK', 'AWS_ACCESS_KEY_ID', 'AZURE_API_KEY']) {
    const previous = process.env[key]
    process.env[key] = 'test-only'
    t.after(() => { if (previous === undefined) { delete process.env[key] } else { process.env[key] = previous } })
    assert.equal(spawnEnvironment()[key], undefined)
  }
})

test('Claude project settings cannot inject paid credentials after authentication preflight', () => {
  assert.throws(() => SubscriptionPolicy.claudeSettings({ env: { ANTHROPIC_API_KEY: 'test-only' } }), /paid-provider/)
  assert.throws(() => SubscriptionPolicy.claudeSettings({ apiKeyHelper: 'printf test-only' }), /paid-provider/)
  assert.throws(() => SubscriptionPolicy.claudeSettings({ env: { CLAUDE_CODE_USE_VERTEX: '1' } }), /paid-provider/)
  assert.throws(() => SubscriptionPolicy.claudeSettings({ env: { ANTHROPIC_BASE_URL: 'https://gateway.example' } }), /paid-provider/)
  assert.doesNotThrow(() => SubscriptionPolicy.claudeSettings({ env: { CLAUDE_CODE_USE_VERTEX: '0', CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: '1' } }))
})

test('each reported Codex quota window must be verifiable before starting inference', () => {
  for (const usedPercent of [undefined, null, '99', NaN, Infinity, -1]) {
    assert.throws(() => SubscriptionPolicy.codex({ account: { type: 'chatgpt' } }, { config: {} }, { rateLimits: { primary: { usedPercent: 20 }, secondary: { usedPercent } } }), /Cannot verify/)
  }
  assert.doesNotThrow(() => SubscriptionPolicy.codex({ account: { type: 'chatgpt' } }, { config: {} }, { rateLimits: { primary: { usedPercent: 20 }, secondary: null } }))
})

test('non-inference shell access skips capacity but never account or provider enforcement', () => {
  const options = { capacity: false }
  const quota = { rateLimits: { primary: { usedPercent: 100 } } }
  assert.doesNotThrow(() => SubscriptionPolicy.codex({ account: { type: 'chatgpt' } }, { config: {} }, quota, options))
  assert.throws(() => SubscriptionPolicy.codex({ account: { type: 'apiKey' } }, { config: {} }, quota, options), /API key billing/)
  assert.throws(() => SubscriptionPolicy.codex({ account: { type: 'chatgpt' } }, { config: { model_providers: { openai: { apiKey: 'test' } } } }, quota, options), /built-in OpenAI provider/)
})


test('Claude configuration audits managed fragments and real workspace ancestry before auth', (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'afto-claude-settings-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  for (const name of ['home', 'managed/managed-settings.d', 'actual/project', 'actual/.claude']) {
    fs.mkdirSync(path.join(root, name), { recursive: true })
  }
  fs.symlinkSync(path.join(root, 'actual/project'), path.join(root, 'alias'))
  const options = { home: path.join(root, 'home'), managedPaths: [path.join(root, 'managed/managed-settings.json')] }
  const fragment = path.join(root, 'managed/managed-settings.d/policy.json')
  fs.writeFileSync(fragment, JSON.stringify({ policyHelper: 'paid-helper' }))
  assert.throws(() => requireClaudeConfiguration(path.join(root, 'alias'), options), /paid-provider/)
  fs.writeFileSync(fragment, '{}')
  fs.writeFileSync(path.join(root, 'actual/.claude/settings.local.json'), JSON.stringify({ env: { ANTHROPIC_BASE_URL: 'https://gateway.example' } }))
  assert.throws(() => requireClaudeConfiguration(path.join(root, 'alias'), options), /paid-provider/)
  fs.writeFileSync(path.join(root, 'actual/.claude/settings.local.json'), '{}')
  assert.doesNotThrow(() => requireClaudeConfiguration(path.join(root, 'alias'), options))
  fs.writeFileSync(fragment, '{')
  assert.throws(() => requireClaudeConfiguration(path.join(root, 'alias'), options), /could not be verified/)
  fs.writeFileSync(fragment, '[]')
  assert.throws(() => requireClaudeConfiguration(path.join(root, 'alias'), options), /could not be verified/)
})

test('Claude configuration includes filesystem-root settings and treats credentials as values, not flags', (t) => {
  const exists = fs.existsSync
  const read = fs.readFileSync
  t.after(() => { fs.existsSync = exists; fs.readFileSync = read })
  fs.existsSync = file => file === '/.claude/settings.local.json' || exists(file)
  fs.readFileSync = (file, ...args) => file === '/.claude/settings.local.json' ? '{"env":{"ANTHROPIC_AUTH_TOKEN":"false"}}' : read(file, ...args)
  assert.throws(() => requireClaudeConfiguration(os.tmpdir(), { home: os.tmpdir(), managedPaths: [] }), /paid-provider/)
  for (const value of ['0', 'false', false]) {
    assert.throws(() => SubscriptionPolicy.claudeSettings({ env: { ANTHROPIC_API_KEY: value } }), /paid-provider/)
    assert.doesNotThrow(() => SubscriptionPolicy.claudeSettings({ env: { CLAUDE_CODE_USE_VERTEX: value } }))
  }
  assert.throws(() => SubscriptionPolicy.claudeSettings({ forceLoginMethod: 'unsupported-provider' }), /paid-provider/)
})
