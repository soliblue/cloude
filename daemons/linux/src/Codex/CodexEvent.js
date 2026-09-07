export const normalizedMethods = new Set([
  'item/plan/delta', 'item/agentMessage/delta', 'item/reasoning/summaryTextDelta', 'item/reasoning/textDelta',
  'item/commandExecution/outputDelta', 'item/fileChange/outputDelta', 'item/mcpToolCall/progress',
  'thread/tokenUsage/updated', 'turn/plan/updated', 'item/started', 'item/completed',
  'thread/compacted', 'turn/completed', 'serverRequest/resolved', 'error'
])

export function normalizedItem(item, completed = false) {
  if (item.type === 'enteredReviewMode') { return [] }
  if (item.type === 'exitedReviewMode') { return completed && item.review ? [{ type: 'assistant', message: { content: [{ type: 'text', text: item.review }] } }] : [] }
  if (item.type === 'plan') { return [{ type: 'plan', itemId: item.id, text: item.text || '', delta: false, completed }] }
  if (item.type === 'agentMessage') {
    return completed ? [{ type: 'assistant', message: { content: [{ type: 'text', text: item.text }] } }] : []
  }
  if (item.type === 'reasoning') {
    return completed ? [{ type: 'assistant', message: { content: [{ type: 'thinking', thinking: (item.summary || []).join('\n') }] } }] : []
  }
  if (item.type === 'userMessage') {
    return []
  }
  const name = { commandExecution: 'Bash', fileChange: 'Edit', webSearch: 'WebSearch', collabAgentToolCall: 'Agent', subAgentActivity: 'Agent' }[item.type] || item.tool || item.type
  const input = item.type === 'commandExecution' ? { command: item.command, cwd: item.cwd } : item.type === 'webSearch' ? { query: item.query, action: item.action } : item.type === 'fileChange' ? { file_path: item.changes?.map((change) => change.path).join(', '), changes: item.changes } : item.arguments || item
  return completed
    ? [{ type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: item.id, content: item.type === 'imageGeneration' ? JSON.stringify(item) : item.aggregatedOutput ?? JSON.stringify(item.result ?? item.changes ?? item), is_error: item.status === 'failed' || Boolean(item.error) || (item.type === 'imageGeneration' && Boolean(item.failure)) || (typeof item.exitCode === 'number' && item.exitCode !== 0) }] } }]
    : [{ type: 'assistant', message: { content: [{ type: 'tool_use', id: item.id, name, input }] } }]
}

export function normalizedNotification(method, params) {
  let events = []
  if (method === 'item/plan/delta') { events = [{ type: 'plan', itemId: params.itemId, text: params.delta, delta: true, completed: false }] }
  if (method === 'item/agentMessage/delta' || method === 'item/reasoning/summaryTextDelta' || method === 'item/reasoning/textDelta') {
    events = [{ type: 'stream_event', event: { type: 'content_block_delta', delta: method === 'item/agentMessage/delta' ? { type: 'text_delta', text: params.delta } : { type: 'thinking_delta', thinking: params.delta } } }]
  }
  if (method === 'turn/plan/updated') {
    events = [{ type: 'assistant', message: { content: [{ type: 'tool_use', id: `plan:${params.turnId}`, name: 'TodoWrite', input: { todos: (params.plan || []).map((step) => ({ content: step.step, status: step.status === 'inProgress' ? 'in_progress' : step.status, activeForm: step.step })), explanation: params.explanation } }] } }]
  }
  if (method === 'item/started' || method === 'item/completed') {
    events = normalizedItem(params.item, method === 'item/completed')
  }
  return events.map(event => ({ ...event, ...(params.itemId || params.item?.id ? { itemId: params.itemId || params.item.id } : {}), ...(params.turnId ? { turnId: params.turnId } : {}) }))
}
