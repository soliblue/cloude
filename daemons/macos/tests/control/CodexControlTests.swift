import Foundation

@main struct CodexControlTests {
    static func main() {
        for mode in ["active", "idle", "stale-review", "foreign", "failure", "interrupt-failure"] {
            CodexHandler.calls = []
            CodexHandler.handler = { method, _ in
                if mode == "failure" || mode == "interrupt-failure" && method == "turn/interrupt" { return nil }
                if method == "turn/interrupt" { return [:] }
                return [
                    "thread": [
                        "id": mode == "foreign" ? "other" : "child-thread",
                        "status": ["type": mode == "idle" ? "idle" : "active"],
                        "turns": [
                            ["id": "old-review", "status": "inProgress"],
                            ["id": "current-turn", "status": mode == "stale-review" ? "completed" : "inProgress"],
                        ],
                    ]
                ]
            }
            let response = CodexControlHandler.abort(sessionId: "imported")
            let expected = [
                "active": 200, "idle": 200, "stale-review": 409, "foreign": 502, "failure": 502,
                "interrupt-failure": 502,
            ][mode]!
            precondition(response.status == expected, mode)
            precondition(CodexHandler.calls.count == (["active", "interrupt-failure"].contains(mode) ? 2 : 1), mode)
            if let call = CodexHandler.calls.first(where: { $0.0 == "turn/interrupt" }) {
                precondition(
                    call.1["threadId"] as? String == "child-thread" && call.1["turnId"] as? String == "current-turn")
            }
            precondition(CodexHandler.calls.allSatisfy { ["thread/read", "turn/interrupt"].contains($0.0) })
        }
        CodexHandler.calls = []
        precondition(CodexControlHandler.abort(sessionId: "unmapped").status == 200)
        precondition(CodexHandler.calls.isEmpty)
        print(
            "Native remote control: imported child interruption, exact native thread/last-turn matching, inactive tasks, stale review turns and failed confirmations passed"
        )
    }
}
