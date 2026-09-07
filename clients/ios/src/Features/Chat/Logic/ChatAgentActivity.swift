import Foundation

nonisolated struct ChatAgentActivity: Identifiable {
    let id: String
    let status: String
    let text: String
    var name: String? = nil

    var isRunning: Bool { ["running", "pendingInit", "pending", "inProgress"].contains(status) }

    var title: String {
        switch status {
        case "pendingInit": "Starting"
        case "inProgress": "Running"
        case "notFound": "Unavailable"
        case "errored", "failed": "Failed"
        case "interacted": "Updated"
        case "unknown": "Status unavailable"
        default: status.capitalized
        }
    }

    var symbol: String {
        switch status {
        case "completed": "checkmark.circle"
        case "errored", "failed", "notFound": "exclamationmark.circle"
        case "interrupted", "shutdown": "pause.circle"
        default: "circle.dotted"
        }
    }

    static func label(_ input: [String: Any]) -> String {
        if let path = input["agentPath"] as? String, let name = path.split(separator: "/").last { return String(name) }
        if let description = input["description"] as? String, !description.isEmpty { return description }
        if let tool = input["tool"] as? String {
            return [
                "spawnAgent": "Start agent", "sendInput": "Message agent", "resumeAgent": "Resume agent",
                "wait": "Wait for agents", "closeAgent": "Close agent", "sendMessage": "Message agent",
                "followupTask": "Follow up with agent", "interruptAgent": "Interrupt agent",
                "listAgents": "List agents",
            ][tool] ?? "Agent"
        }
        if let role = input["subagent_type"] as? String, !role.isEmpty { return role }
        return "Agent"
    }

    static func collect(input: [String: Any], result: [String: Any]) -> [ChatAgentActivity] {
        if let threadId = result["agentThreadId"] as? String ?? input["agentThreadId"] as? String, !threadId.isEmpty {
            return [
                ChatAgentActivity(
                    id: threadId,
                    status: result["kind"] as? String ?? input["kind"] as? String ?? "unknown", text: "",
                    name: (result["agentPath"] as? String ?? input["agentPath"] as? String)?.split(separator: "/").last
                        .map(String.init))
            ]
        }
        let states = result["agentsStates"] as? [String: Any] ?? input["agentsStates"] as? [String: Any] ?? [:]
        let receiverIds = result["receiverThreadIds"] as? [String] ?? input["receiverThreadIds"] as? [String] ?? []
        return Set(Array(states.keys) + receiverIds).filter { !$0.isEmpty }.sorted().map { id in
            let state = states[id] as? [String: Any] ?? [:]
            return ChatAgentActivity(
                id: id, status: state["status"] as? String ?? "unknown", text: state["message"] as? String ?? "")
        }
    }
}
