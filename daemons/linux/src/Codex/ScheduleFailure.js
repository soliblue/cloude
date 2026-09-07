export function scheduleFailure(message = '', hasThread = false) {
  if (/subscription usage limit reached/i.test(message)) { return 'Codex subscription usage limit reached. Wait for its reset; paid credits are not used.' }
  if (/Cannot verify Codex subscription capacity/i.test(message)) { return 'Cannot verify Codex subscription capacity. Check the endpoint account and retry.' }
  if (/Sign in to Codex|account.*chatgpt/i.test(message)) { return 'Sign in to Codex on this endpoint with your ChatGPT subscription. API key billing is not supported.' }
  if (/model_providers|built-in OpenAI|subscription-backed OpenAI/i.test(message)) { return 'Remove custom OpenAI provider overrides from this endpoint to use your Codex subscription.' }
  if (/custom inference endpoints/i.test(message)) { return 'Remove custom inference endpoint URLs from this endpoint to use your Codex subscription.' }
  if (/ENOENT|ENOTDIR|working directory/i.test(message)) { return 'The agent executable or working directory is unavailable. Check the endpoint installation and schedule path.' }
  if (/timed out|disconnected|connection closed|app-server exited/i.test(message)) { return 'Codex could not stay connected on this endpoint. Check the host connection and retry.' }
  return hasThread ? 'The scheduled agent stopped with an error. Open the run to inspect its output.' : 'Codex could not start. Check the endpoint installation, subscription login and provider settings, then retry.'
}
