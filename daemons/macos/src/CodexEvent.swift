import Foundation

nonisolated enum CodexEvent {
    static let normalizedMethods: Set<String> = [
        "item/agentMessage/delta", "item/reasoning/summaryTextDelta", "item/reasoning/textDelta",
        "item/commandExecution/outputDelta", "item/fileChange/outputDelta", "item/mcpToolCall/progress",
        "thread/tokenUsage/updated", "turn/plan/updated", "item/plan/delta", "item/started", "item/completed",
        "thread/compacted", "turn/completed", "serverRequest/resolved", "error",
    ]

    static func envelopes(method: String, params: [String: Any]) -> [[String: Any]] {
        var envelopes: [[String: Any]] = []
        switch method {
        case "item/agentMessage/delta", "item/reasoning/summaryTextDelta", "item/reasoning/textDelta":
            if let delta = params["delta"] as? String {
                envelopes.append([
                    "event": [
                        "type": "stream_event",
                        "event": [
                            "type": "content_block_delta",
                            "delta": [
                                "type": method == "item/agentMessage/delta" ? "text_delta" : "thinking_delta",
                                (method == "item/agentMessage/delta" ? "text" : "thinking"): delta,
                            ],
                        ],
                    ]
                ])
            }
        case "item/commandExecution/outputDelta", "item/fileChange/outputDelta":
            if let id = params["itemId"] as? String {
                envelopes.append([
                    "type": "tool_output_delta", "toolUseId": id, "text": params["delta"] as? String ?? "",
                ])
            }
        case "item/mcpToolCall/progress":
            if let id = params["itemId"] as? String {
                envelopes.append([
                    "type": "tool_output_delta", "toolUseId": id, "text": (params["message"] as? String ?? "") + "\n",
                ])
            }
        case "item/plan/delta":
            if let id = params["itemId"] as? String, let delta = params["delta"] as? String {
                envelopes.append([
                    "event": [
                        "type": "plan", "itemId": id, "text": delta, "delta": true, "completed": false,
                    ]
                ])
            }
        case "thread/tokenUsage/updated":
            let usage = params["tokenUsage"] as? [String: Any] ?? [:]
            var event: [String: Any] = ["type": "usage"]
            event["contextTokens"] = (usage["last"] as? [String: Any])?["totalTokens"]
            event["contextWindow"] = usage["modelContextWindow"]
            event["inputTokens"] = (usage["total"] as? [String: Any])?["inputTokens"]
            event["outputTokens"] = (usage["total"] as? [String: Any])?["outputTokens"]
            envelopes.append(event)
        case "turn/plan/updated":
            if let turnId = params["turnId"] as? String {
                envelopes.append([
                    "event": [
                        "type": "assistant",
                        "message": [
                            "content": [
                                [
                                    "type": "tool_use", "id": "plan:" + turnId, "name": "TodoWrite",
                                    "input": [
                                        "todos": ((params["plan"] as? [[String: Any]]) ?? []).map { step in
                                            var todo: [String: Any] = [
                                                "content": step["step"] as? String ?? "",
                                                "status": (step["status"] as? String) == "inProgress"
                                                    ? "in_progress" : step["status"] as? String ?? "pending",
                                                "activeForm": step["step"] as? String ?? "",
                                            ]
                                            if let explanation = step["explanation"] as? String {
                                                todo["explanation"] = explanation
                                            }
                                            return todo
                                        }
                                    ],
                                ]
                            ]
                        ],
                    ]
                ])
            }
        case "item/started", "item/completed":
            if let item = params["item"] as? [String: Any], let type = item["type"] as? String {
                let completed = method == "item/completed"
                if type == "enteredReviewMode" {
                    if !completed {
                        envelopes.append(["type": "status", "state": "reviewing", "message": "Reviewing changes"])
                    }
                } else if type == "exitedReviewMode" {
                    if completed {
                        envelopes.append(["type": "status", "state": "review_complete", "message": "Review completed"])
                        if let review = item["review"] as? String, !review.isEmpty {
                            envelopes.append([
                                "event": [
                                    "type": "assistant", "message": ["content": [["type": "text", "text": review]]],
                                ]
                            ])
                        }
                    }
                } else if type == "plan" {
                    if let id = item["id"] as? String {
                        let text = item["text"] as? String ?? ""
                        envelopes.append([
                            "event": [
                                "type": "plan", "itemId": id, "text": text, "delta": false, "completed": completed,
                            ]
                        ])
                    }
                } else if type == "agentMessage" {
                    if completed {
                        envelopes.append([
                            "event": [
                                "type": "assistant",
                                "message": ["content": [["type": "text", "text": item["text"] as? String ?? ""]]],
                            ]
                        ])
                    }
                } else if type == "reasoning" {
                    if completed {
                        envelopes.append([
                            "event": [
                                "type": "assistant",
                                "message": [
                                    "content": [
                                        [
                                            "type": "thinking",
                                            "thinking": (item["summary"] as? [String] ?? []).joined(separator: "\n"),
                                        ]
                                    ]
                                ],
                            ]
                        ])
                    }
                } else if type != "userMessage", let id = item["id"] as? String {
                    if completed {
                        let error =
                            item["error"].map { value in
                                if let number = value as? NSNumber { return number.boolValue }
                                if let text = value as? String { return !text.isEmpty }
                                return !(value is NSNull)
                            } ?? false
                        let failure = item["failure"].map { !($0 is NSNull) } ?? false
                        let output =
                            type == "imageGeneration"
                            ? (try? JSONSerialization.data(withJSONObject: item, options: [.sortedKeys])).flatMap {
                                String(data: $0, encoding: .utf8)
                            } ?? ""
                            : item["aggregatedOutput"] as? String
                                ?? (try? JSONSerialization.data(
                                    withJSONObject: [item["result"], item["changes"]].compactMap { $0 }.first {
                                        !($0 is NSNull)
                                    } ?? item,
                                    options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes])).flatMap {
                                    String(data: $0, encoding: .utf8)
                                } ?? ""
                        envelopes.append([
                            "event": [
                                "type": "user",
                                "message": [
                                    "content": [
                                        [
                                            "type": "tool_result", "tool_use_id": id, "content": output,
                                            "is_error": item["status"] as? String == "failed" || error
                                                || failure
                                                || (item["exitCode"] as? Int).map { $0 != 0 } == true,
                                        ]
                                    ]
                                ],
                            ]
                        ])
                    } else {
                        var input = item["arguments"].flatMap { $0 is NSNull ? nil : $0 } ?? item
                        if type == "commandExecution" {
                            var fields: [String: Any] = [:]
                            fields["command"] = item["command"]
                            fields["cwd"] = item["cwd"]
                            input = fields
                        } else if type == "webSearch" {
                            var fields: [String: Any] = [:]
                            fields["query"] = item["query"]
                            fields["action"] = item["action"]
                            input = fields
                        } else if type == "fileChange" {
                            let changes = item["changes"] as? [[String: Any]] ?? []
                            input = [
                                "file_path": changes.compactMap { $0["path"] as? String }.joined(separator: ", "),
                                "changes": changes,
                            ]
                        }
                        envelopes.append([
                            "event": [
                                "type": "assistant",
                                "message": [
                                    "content": [
                                        [
                                            "type": "tool_use", "id": id,
                                            "name": [
                                                "commandExecution": "Bash", "fileChange": "Edit",
                                                "webSearch": "WebSearch", "collabAgentToolCall": "Agent",
                                                "subAgentActivity": "Agent",
                                            ][type] ?? item["tool"] as? String ?? type,
                                            "input": input,
                                        ]
                                    ]
                                ],
                            ]
                        ])
                    }
                }
                if !completed && type == "contextCompaction" {
                    envelopes.append(["type": "status", "state": "compacting"])
                }
            }
        case "thread/compacted":
            envelopes.append(["type": "status", "state": "compacting"])
        case "turn/completed":
            if let turn = params["turn"] as? [String: Any], let status = turn["status"] as? String {
                if status == "failed" {
                    envelopes.append([
                        "type": "error",
                        "message": (turn["error"] as? [String: Any])?["message"] as? String ?? "Codex turn failed",
                    ])
                }
                if status == "interrupted" { envelopes.append(["type": "aborted"]) }
                envelopes.append(["event": ["type": "result", "subtype": status, "is_error": status == "failed"]])
            }
        case "error":
            if params["willRetry"] as? Bool != true {
                envelopes.append([
                    "type": "error",
                    "message": (params["error"] as? [String: Any])?["message"] as? String ?? "Codex error",
                ])
            }
        default:
            break
        }
        return envelopes
    }
}
