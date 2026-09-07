import Foundation

enum ChatToolCall {
    static func summarize(name: String, input: [String: Any]) -> String { name }
    static func prettyJSON(_ object: Any) -> String {
        String(data: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), encoding: .utf8)!
    }
}

let approval = ChatStreamEvent.decode(
    Data(
        #"{"seq":9,"type":"request","requestId":"42","method":"item/commandExecution/requestApproval","params":{"command":"git status"}}"#
            .utf8))!
if case .request(let seq, let interaction) = approval {
    precondition(seq == 9 && interaction.id == "42" && interaction.detail == "git status")
} else {
    fatalError("Approval was not decoded")
}

let question = ChatStreamEvent.decode(
    Data(
        #"{"seq":10,"type":"request","requestId":"43","method":"item/tool/requestUserInput","params":{"questions":[{"id":"color","question":"Which color?","options":[{"label":"Blue","description":"Cool"}]}]}}"#
            .utf8))!
if case .request(_, let interaction) = question {
    precondition(interaction.questions.first?.id == "color")
    precondition(interaction.questions.first?.options == ["Blue"])
    precondition(interaction.questions.first?.optionDescriptions["Blue"] == "Cool")
} else {
    fatalError("Question was not decoded")
}

let resolved = ChatStreamEvent.decode(Data(#"{"seq":11,"type":"request_resolved","requestId":"43"}"#.utf8))!
if case .requestResolved(let seq, let id) = resolved {
    precondition(seq == 11 && id == "43")
} else {
    fatalError("Resolution was not decoded")
}

let tool = ChatStreamEvent.decode(
    Data(
        #"{"seq":12,"event":{"type":"assistant","message":{"model":"gpt-test","content":[{"type":"tool_use","id":"search-1","name":"WebSearch","input":{"query":"release notes"}}]}}}"#
            .utf8))!
if case .assistantFinal(_, _, _, _, let uses, let model, _, _, _) = tool {
    precondition(uses.count == 1 && uses[0].name == "WebSearch" && model == "gpt-test")
} else {
    fatalError("Normalized Codex tool was not decoded")
}

let delta = ChatStreamEvent.decode(
    Data(
        #"{"seq":13,"event":{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"hello"}}}}"#
            .utf8))!
if case .assistantTextDelta(let seq, let text, _, _) = delta {
    precondition(seq == 13 && text == "hello")
} else {
    fatalError("Text delta was not decoded")
}

precondition(ChatStreamEvent.decode(Data("invalid".utf8)) == nil)
precondition(ChatStreamEvent.decode(Data(#"{"event":{}}"#.utf8)) == nil)
print("Passed 7 chat wire decoding checks")

let output = ChatStreamEvent.decode(
    Data(#"{"seq":14,"type":"tool_output_delta","toolUseId":"command-1","text":"building…"}"#.utf8))!
if case .toolOutputDelta(let seq, let id, let text) = output {
    precondition(seq == 14 && id == "command-1" && text == "building…")
} else {
    fatalError("Live tool output was not decoded")
}

let metadata = ChatStreamEvent.decode(
    Data(#"{"seq":15,"type":"session","threadId":"thread-1","provider":"codex"}"#.utf8))!
if case .sessionMetadata(let seq, let threadId) = metadata {
    precondition(seq == 15 && threadId == "thread-1")
} else {
    fatalError("Thread metadata was not decoded")
}
print("Passed live tool output and thread metadata checks")

let usage = ChatStreamEvent.decode(
    Data(#"{"seq":16,"type":"usage","contextTokens":1234,"contextWindow":200000}"#.utf8))!
if case .usage(let seq, let tokens, let window) = usage {
    precondition(seq == 16 && tokens == 1234 && window == 200000)
} else {
    fatalError("Context usage was not decoded")
}
let permissions = ChatInteraction(
    id: "permission", method: "item/permissions/requestApproval",
    paramsJSON: #"{"permissions":{"network":{"enabled":true}}}"#)
precondition(permissions.approvalResult("decline")["permissions"] as? [String: Bool] == [:])
precondition(permissions.approvalResult("acceptForSession")["scope"] as? String == "session")
let form = ChatInteraction(
    id: "form", method: "mcpServer/elicitation/request",
    paramsJSON:
        #"{"requestedSchema":{"type":"object","required":["age"],"properties":{"age":{"type":"integer"},"ok":{"type":"boolean","default":false}}}}"#
)
precondition(form.questions.first(where: { $0.id == "age" })?.value("invalid") == nil)
let content = form.answersResult(["age": "25", "ok": "true"])["content"] as! [String: Any]
precondition(content["age"] as? Int == 25 && content["ok"] as? Bool == true)
print("Passed context usage, permission response, and typed MCP form checks")

let parallel = ChatStreamEvent.decode(
    Data(
        #"{"seq":17,"event":{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"a","content":"one"},{"type":"tool_result","tool_use_id":"b","content":"two","is_error":true}]}}}"#
            .utf8))!
if case .toolResults(let seq, let results) = parallel {
    precondition(seq == 17 && results.count == 2 && results[1].id == "b" && results[1].isError)
} else {
    fatalError("Parallel tool results were lost")
}
print("Passed parallel Claude/Codex tool result preservation")

let initialized = ChatStreamEvent.decode(
    Data(#"{"seq":18,"event":{"type":"system","subtype":"init","model":"gpt-example"}}"#.utf8))!
if case .initialized(let seq, let model) = initialized {
    precondition(seq == 18 && model == "gpt-example")
} else {
    fatalError("Resolved model from initialization was lost")
}
print("Passed resolved model metadata")

let store = ChatInteractionStore()
let sessionId = UUID()
let pendingRequest = ChatInteraction(id: "pending", method: "item/commandExecution/requestApproval", paramsJSON: "{}")
let originalRevision = store.revisions[sessionId, default: 0]
precondition(store.add(pendingRequest, sessionId: sessionId))
precondition(!store.replace([], sessionId: sessionId, revision: originalRevision))
precondition(store.requests[sessionId]?.count == 1)
let beforeResolution = store.revisions[sessionId, default: 0]
store.remove(pendingRequest.id, sessionId: sessionId)
precondition(!store.replace([pendingRequest], sessionId: sessionId, revision: beforeResolution))
precondition(store.requests[sessionId]?.isEmpty == true)
let beforeClear = store.revisions[sessionId, default: 0]
store.clear(sessionId: sessionId)
precondition(!store.replace([pendingRequest], sessionId: sessionId, revision: beforeClear))
let afterClear = store.revisions[sessionId, default: 0]
precondition(store.replace([pendingRequest], sessionId: sessionId, revision: afterClear))
precondition(!store.add(pendingRequest, sessionId: sessionId))
print("Passed approval refresh races, resolved request preservation, clearing, and duplicate suppression")

let enumForm = ChatInteraction(
    id: "enum-form", method: "mcpServer/elicitation/request",
    paramsJSON:
        #"{"requestedSchema":{"type":"object","required":["color"],"properties":{"color":{"type":"string","enum":["red","blue"]}}}}"#
)
precondition(enumForm.questions[0].value("green") == nil)
precondition(enumForm.questions[0].value("red") as? String == "red")
print("Passed option explanations and required MCP choice validation")

let agentNotice = ChatStreamEvent.decode(
    Data(#"{"seq":30,"type":"agent_attention","threadId":"real-child","requestId":"process:42","pending":true}"#.utf8))!
if case .agentAttention(let seq, let threadId, let requestId, let pending) = agentNotice {
    precondition(seq == 30 && threadId == "real-child" && requestId == "process:42" && pending)
} else {
    fatalError("Child attention must not become an interactive parent approval")
}
let agentResolved = ChatStreamEvent.decode(
    Data(#"{"seq":31,"type":"agent_attention","threadId":"real-child","requestId":"process:42","pending":false}"#.utf8))!
if case .agentAttention(_, _, _, let pending) = agentResolved {
    precondition(!pending)
} else {
    fatalError("Child attention resolution missing")
}
let ancestorId = UUID()
let attentionStore = ChatInteractionStore()
attentionStore.updateAgent(threadId: "real-child", requestId: "process:42", pending: true, sessionId: ancestorId)
attentionStore.updateAgent(threadId: "real-child", requestId: "process:42", pending: true, sessionId: ancestorId)
precondition(
    attentionStore.agentRequests[ancestorId]?.count == 1 && attentionStore.requests[ancestorId] == nil
        && attentionStore.hasAttention(sessionId: ancestorId))
let oldRevision = attentionStore.agentRevisions[ancestorId]!
attentionStore.updateAgent(threadId: "real-child", requestId: "process:42", pending: false, sessionId: ancestorId)
precondition(
    !attentionStore.replaceAgents(
        [ChatAgentAttention(threadId: "real-child", requestId: "process:42")], sessionId: ancestorId,
        revision: oldRevision))
precondition(!attentionStore.hasAttention(sessionId: ancestorId))
print(
    "Passed child attention routing separate from parent approvals, opaque IDs, deduplication and stale snapshot resolution"
)

let planPreview = ChatStreamEvent.decode(
    Data(#"{"seq":201,"event":{"type":"plan","itemId":"plan-a","text":"Draft","delta":true,"completed":false}}"#.utf8))!
if case .plan(let seq, let id, let text, let delta, let completed) = planPreview {
    precondition(seq == 201 && id == "plan-a" && text == "Draft" && delta && !completed)
} else {
    fatalError("Plan preview did not decode")
}
let planFinal = ChatStreamEvent.decode(
    Data(
        #"{"seq":202,"event":{"type":"plan","itemId":"plan-a","text":"Different final","delta":false,"completed":true}}"#
            .utf8))!
if case .plan(let seq, let id, let text, let delta, let completed) = planFinal {
    precondition(seq == 202 && id == "plan-a" && text == "Different final" && !delta && completed)
} else {
    fatalError("Plan final did not decode")
}
precondition(planPreview.seq == 201 && planFinal.seq == 202)
print("PASS item-scoped plan delta and authoritative final wire")
