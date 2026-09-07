import Foundation

final class ChatMessage {
    enum Role { case user, assistant }
    enum State { case complete, streaming, failed, retrying, queued }
    let id = UUID()
    var text = ""
    var state = State.complete
    var imagesData: [Data] = []
    var hasThinking = false
    var hasToolCalls = false
    let role: Role
    init(role: Role) { self.role = role }
}

let messages = (0..<20000).map { _ in ChatMessage(role: .assistant) }
let legacyStart = Date()
var legacy: [[ChatMessage]] = []
for message in messages {
    if var last = legacy.last, last.first?.role == message.role {
        last.append(message)
        legacy[legacy.count - 1] = last
    } else {
        legacy.append([message])
    }
}
let legacyDuration = Date().timeIntervalSince(legacyStart)
let optimizedStart = Date()
let store = ChatMessageGroupStore()
let groups = store.groups(for: messages)
let optimizedDuration = Date().timeIntervalSince(optimizedStart)
precondition(groups.count == 1 && groups[0].messages.map(\.id) == messages.map(\.id))
precondition(legacy.count == groups.count && legacy[0].map(\.id) == groups[0].messages.map(\.id))
precondition(store.groups(for: messages)[0].groupId == messages[0].id)
let second = messages + [ChatMessage(role: .user), ChatMessage(role: .assistant)]
precondition(store.groups(for: second).count == 3)
precondition(store.groups(for: Array(second.dropLast())).count == 2)
print(
    "20,000-message grouping: legacy \(String(format: "%.3f", legacyDuration * 1000))ms, optimized \(String(format: "%.3f", optimizedDuration * 1000))ms"
)
print("Passed grouping order, role boundaries, stable identity, cache invalidation")

let turns = (0..<20000).map { ChatMessage(role: $0.isMultiple(of: 2) ? .user : .assistant) }
let turnsStart = Date()
let turnGroups = store.groups(for: turns)
let turnsDuration = Date().timeIntervalSince(turnsStart)
precondition(turnGroups.count == 20000)
let cachedStart = Date()
var consumed = 0
for _ in 0..<100 { consumed += store.groups(for: turns).count }
let cachedDuration = Date().timeIntervalSince(cachedStart)
precondition(consumed == 2_000_000)
turns[0].text = "updated imported text"
precondition(store.groups(for: turns)[0].messages[0].text == "updated imported text")
print(
    "20,000 alternating turns: first grouping \(String(format: "%.3f", turnsDuration * 1000))ms, 100 cached lookups \(String(format: "%.3f", cachedDuration * 1000))ms"
)

for message in messages { message.hasThinking = true }
let thinkingStart = Date()
let segments = ChatMessageSegment.build(from: messages)
let thinkingDuration = Date().timeIntervalSince(thinkingStart)
precondition(segments.count == 1)
if case .thinking(let run) = segments[0] {
    precondition(run.map(\.id) == messages.map(\.id))
} else {
    preconditionFailure("Expected thinking run")
}
messages[5].hasToolCalls = true
messages[6].text = "visible response"
messages[7].state = .streaming
let mixed = ChatMessageSegment.build(from: Array(messages.prefix(10)))
precondition(mixed.count == 5)
if case .thinking(let run) = mixed[0] { precondition(run.count == 6) } else { preconditionFailure() }
if case .tools(let ids) = mixed[1] { precondition(ids == [messages[5].id]) } else { preconditionFailure() }
if case .message(let message) = mixed[2] { precondition(message.id == messages[6].id) } else { preconditionFailure() }
if case .message(let message) = mixed[3] { precondition(message.state == .streaming) } else { preconditionFailure() }
if case .thinking(let run) = mixed[4] { precondition(run.count == 2) } else { preconditionFailure() }
print(
    "20,000 reasoning segments: \(String(format: "%.3f", thinkingDuration * 1000))ms; mixed tool/text/stream ordering preserved"
)
