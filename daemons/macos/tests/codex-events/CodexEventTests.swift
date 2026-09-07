import Foundation

@main struct CodexEventTests {
    static func decode(_ method: String, _ params: [String: Any]) -> [ChatStreamEvent] {
        CodexEvent.envelopes(method: method, params: params).enumerated().map { index, value in
            precondition(value["codex"] == nil && value["type"] as? String != "exit")
            var envelope = value
            envelope["seq"] = index
            return ChatStreamEvent.decode(try! JSONSerialization.data(withJSONObject: envelope))!
        }
    }

    static func main() {
        if case .assistantTextDelta(_, let text) = decode("item/agentMessage/delta", ["delta": "Hello 日本"])[0] {
            precondition(text == "Hello 日本")
        } else {
            preconditionFailure()
        }
        for method in ["item/reasoning/summaryTextDelta", "item/reasoning/textDelta"] {
            if case .assistantThinkingDelta(_, let text) = decode(method, ["delta": "Live reasoning"])[0] {
                precondition(text == "Live reasoning")
            } else {
                preconditionFailure("Reasoning was not decoded")
            }
        }
        precondition(decode("item/started", ["item": ["type": "agentMessage", "id": "text"]]).isEmpty)
        if case .assistantFinal(_, let text, _, _, _, _, _) = decode(
            "item/completed", ["item": ["type": "agentMessage", "id": "text", "text": "Full result"]])[0]
        {
            precondition(text == "Full result")
        } else {
            preconditionFailure()
        }
        let planStarted = CodexEvent.envelopes(
            method: "item/started", params: ["item": ["type": "plan", "id": "plan-item", "text": "Inspect files"]])
        let planSnapshot = planStarted[0]["event"] as? [String: Any]
        precondition(
            planSnapshot?["type"] as? String == "plan" && planSnapshot?["itemId"] as? String == "plan-item"
                && planSnapshot?["text"] as? String == "Inspect files" && planSnapshot?["delta"] as? Bool == false
                && planSnapshot?["completed"] as? Bool == false)
        let planDelta =
            CodexEvent.envelopes(
                method: "item/plan/delta", params: ["itemId": "plan-item", "delta": " then test"])[0]["event"]
            as? [String: Any]
        precondition(planDelta?["delta"] as? Bool == true && planDelta?["completed"] as? Bool == false)
        let planCompleted =
            CodexEvent.envelopes(
                method: "item/completed",
                params: ["item": ["type": "plan", "id": "plan-item", "text": "Inspect files then test"]])[0]["event"]
            as? [String: Any]
        precondition(planCompleted?["delta"] as? Bool == false && planCompleted?["completed"] as? Bool == true)
        let planUpdate = CodexEvent.envelopes(
            method: "turn/plan/updated",
            params: [
                "turnId": "turn-1",
                "plan": [["step": "Run tests", "status": "inProgress", "explanation": "Waiting for approval"]],
            ])[0]
        let planUpdateEvent = planUpdate["event"] as! [String: Any]
        let planUpdateMessage = planUpdateEvent["message"] as! [String: Any]
        let planUpdateContent = planUpdateMessage["content"] as! [[String: Any]]
        let planUpdateInput = planUpdateContent[0]["input"] as! [String: Any]
        let planUpdateTodo = (planUpdateInput["todos"] as! [[String: Any]])[0]
        precondition(planUpdateTodo["status"] as? String == "in_progress")
        precondition(planUpdateTodo["explanation"] as? String == "Waiting for approval")
        precondition(CodexEvent.normalizedMethods.contains("item/plan/delta"))
        if case .assistantFinal(_, _, let thinking, _, _, _, _) = decode(
            "item/completed", ["item": ["type": "reasoning", "id": "reason", "summary": ["First", "Second"]]])[0]
        {
            precondition(thinking == "First\nSecond")
        } else {
            preconditionFailure()
        }
        precondition(decode("item/completed", ["item": ["type": "userMessage", "id": "user"]]).isEmpty)
        let items: [(String, [String: Any])] = [
            ("Bash", ["type": "commandExecution", "id": "bash", "command": "pwd", "cwd": "/tmp/project"]),
            (
                "Edit",
                [
                    "type": "fileChange", "id": "edit",
                    "changes": [["path": "a.swift", "diff": "+new", "kind": ["type": "add"]]],
                ]
            ),
            (
                "WebSearch",
                [
                    "type": "webSearch", "id": "web", "query": "documentation",
                    "action": ["type": "search", "query": "documentation"],
                ]
            ),
            ("lookup", ["type": "mcpToolCall", "id": "mcp", "tool": "lookup", "arguments": ["name": "project"]]),
            (
                "Agent",
                [
                    "type": "collabAgentToolCall", "id": "agent", "receiverThreadIds": ["child-1"],
                    "agentsStates": ["child-1": ["status": "running"]],
                ]
            ),
            ("Agent", ["type": "subAgentActivity", "id": "activity", "receiverThreadIds": ["child-1"]]),
        ]
        for (name, item) in items {
            if case .assistantFinal(_, _, _, _, let tools, _, _) = decode("item/started", ["item": item])[0] {
                precondition(tools.count == 1 && tools[0].name == name && tools[0].id == item["id"] as! String)
                precondition(!tools[0].inputJSON.isEmpty)
            } else {
                preconditionFailure()
            }
            var completed = item
            completed["status"] = "completed"
            if case .toolResult(_, let id, let text, let isError) = decode("item/completed", ["item": completed])[0] {
                precondition(id == item["id"] as! String && !isError)
                precondition((try? JSONSerialization.jsonObject(with: Data(text.utf8))) != nil)
            } else {
                preconditionFailure()
            }
        }
        if case .toolResult(_, let id, let text, let isError) = decode(
            "item/completed",
            [
                "item": [
                    "id": "bash", "type": "commandExecution", "aggregatedOutput": "command failed", "exitCode": 2,
                    "status": "completed",
                ]
            ])[0]
        {
            precondition(id == "bash" && text == "command failed" && isError)
        } else {
            preconditionFailure()
        }
        if case .toolResult(_, let id, let text, let isError) = decode(
            "item/completed", ["item": ["id": "mcp", "type": "mcpToolCall", "result": ["ok": true], "error": NSNull()]])[
                0]
        {
            precondition(id == "mcp" && !isError)
            precondition(
                (try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Bool])["ok"] == true)
        } else {
            preconditionFailure()
        }
        for method in ["item/commandExecution/outputDelta", "item/fileChange/outputDelta", "item/mcpToolCall/progress"]
        {
            if case .toolOutputDelta(_, let id, let text) = decode(
                method, ["itemId": "tool", "delta": "output", "message": "progress"])[0]
            {
                precondition(id == "tool" && text == (method == "item/mcpToolCall/progress" ? "progress\n" : "output"))
            } else {
                preconditionFailure()
            }
        }
        if case .assistantFinal(_, _, _, _, let tools, _, _) = decode(
            "turn/plan/updated", ["turnId": "turn-1", "plan": [["step": "Run tests", "status": "in_progress"]]])[0]
        {
            precondition(tools[0].id == "plan:turn-1" && tools[0].name == "TodoWrite")
            let input =
                try! JSONSerialization.jsonObject(with: Data(tools[0].inputJSON.utf8)) as! [String: [[String: String]]]
            precondition(
                input["todos"]?[0] == ["content": "Run tests", "activeForm": "Run tests", "status": "in_progress"])
        } else {
            preconditionFailure()
        }
        if case .usage(_, let context, let maximum) = decode(
            "thread/tokenUsage/updated",
            [
                "tokenUsage": [
                    "last": ["totalTokens": 100], "modelContextWindow": 200000,
                    "total": ["inputTokens": 80, "outputTokens": 20],
                ]
            ])[0]
        {
            precondition(context == 100 && maximum == 200000)
        } else {
            preconditionFailure()
        }
        precondition(CodexEvent.envelopes(method: "thread/tokenUsage/updated", params: [:])[0]["contextTokens"] == nil)
        if case .compacting = decode("thread/compacted", [:])[0] {} else { preconditionFailure() }
        if case .compacting = decode("item/started", ["item": ["id": "compact", "type": "contextCompaction"]]).last! {
        } else {
            preconditionFailure()
        }
        if case .toolResult(_, _, let text, let isError) = decode(
            "item/completed",
            [
                "item": [
                    "id": "null-result", "type": "mcpToolCall", "result": NSNull(), "error": ["message": "Tool failed"],
                ]
            ])[0]
        {
            precondition(isError)
            let payload = try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
            precondition((payload["error"] as? [String: String])?["message"] == "Tool failed")
        } else {
            preconditionFailure("Null result discarded tool error details")
        }
        if case .toolResult(_, let id, let text, let isError) = decode(
            "item/completed",
            [
                "item": [
                    "id": "image", "type": "imageGeneration", "status": "failed", "savedPath": "/tmp/image.png",
                    "failure": "Image generation failed", "result": "opaque-result",
                ]
            ])[0]
        {
            let item = try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
            precondition(id == "image" && isError && item["savedPath"] as? String == "/tmp/image.png")
            precondition(item["failure"] as? String == "Image generation failed")
            precondition(item["result"] as? String == "opaque-result")
        } else {
            preconditionFailure("Image generation item was not preserved")
        }
        let failed = decode("turn/completed", ["turn": ["status": "failed", "error": ["message": "Quota reached"]]])
        if case .error(_, let message) = failed[0] {
            precondition(message == "Quota reached")
        } else {
            preconditionFailure()
        }
        if case .result = failed[1] {} else { preconditionFailure() }
        let aborted = decode("turn/completed", ["turn": ["status": "interrupted"]])
        if case .aborted = aborted[0] {} else { preconditionFailure() }
        if case .result = aborted[1] {} else { preconditionFailure() }
        precondition(decode("error", ["willRetry": true]).isEmpty)
        if case .error(_, let text) = decode("error", ["error": ["message": "Disconnected"]])[0] {
            precondition(text == "Disconnected")
        } else {
            preconditionFailure()
        }
        let reviewing = CodexEvent.envelopes(
            method: "item/started",
            params: ["item": ["id": "review-start", "type": "enteredReviewMode", "review": "Review changes"]])
        precondition(reviewing.count == 1 && reviewing[0]["state"] as? String == "reviewing")
        let review = decode(
            "item/completed",
            ["item": ["id": "review-end", "type": "exitedReviewMode", "review": "Concrete review finding"]])
        if case .assistantFinal(_, let text, _, _, _, _, _) = review.last! {
            precondition(text == "Concrete review finding")
        } else {
            preconditionFailure()
        }
        precondition(decode("unknown", [:]).isEmpty)
        precondition(decode("item/completed", [:]).isEmpty)
        print(
            "Passed native Codex normalization through the actual iOS decoder: text, reasoning, plans, Bash/Edit/Web/MCP/Agent, live output, usage, compaction, errors, interruption, and terminal result without duplicate exit"
        )
    }
}
