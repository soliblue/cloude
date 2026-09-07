import assert from 'node:assert/strict'
import test from 'node:test'
import { normalizedNotification } from '../src/Codex/CodexEvent.js'

test('Codex text and reasoning retain distinct item and turn identities through normalization', () => {
  for (const id of ['equal-first', 'equal-second']) {
    for (const type of ['agentMessage', 'reasoning']) {
      const [event] = normalizedNotification('item/completed', { turnId: 'turn-identity', item: { id, type, text: 'Equal', summary: ['Equal'] } })
      assert.equal(event.itemId, id)
      assert.equal(event.turnId, 'turn-identity')
      assert.equal(event.message.content[0][type === 'agentMessage' ? 'text' : 'thinking'], 'Equal')
    }
    for (const method of ['item/agentMessage/delta', 'item/reasoning/summaryTextDelta', 'item/reasoning/textDelta']) {
      const [event] = normalizedNotification(method, { itemId: id, turnId: 'turn-identity', delta: 'Equal' })
      assert.equal(event.itemId, id)
      assert.equal(event.turnId, 'turn-identity')
    }
  }
})
