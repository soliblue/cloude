import Foundation

@main
struct CodexReviewTests {
    static func events(_ sessionId: String) -> [[String: Any]] {
        ((try? String(contentsOf: CodexJournal.url(sessionId: sessionId), encoding: .utf8)) ?? "")
            .split(separator: "\n").compactMap {
                (try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? [String: Any]
            }
    }

    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let queue = DispatchQueue(label: "afto.review.fixture")
        for mode in [
            "standalone", "delta", "final", "report-first", "approval", "interrupt", "plan", "apikey", "quota",
            "badprovider", "account-transition",
        ] {
            try Data(mode.utf8).write(to: root.appendingPathComponent("mode"))
            let client = CodexClient(executablePath: CommandLine.arguments[1], requestTimeout: 3)
            let runner = CodexRunner(
                sessionId: mode, hasStartedBefore: false, model: nil, effort: nil, permissionMode: nil,
                threadId: nil, reviewTarget: ["type": "uncommittedChanges"], codex: client, queue: queue)
            let finished = DispatchSemaphore(value: 0)
            var approvalRequestId: String?
            runner.onFinish = { finished.signal() }
            queue.async { runner.spawn(path: root.path, prompt: "Review local changes") }
            if mode == "approval" || mode == "interrupt" {
                let deadline = Date().addingTimeInterval(4)
                while Date() < deadline {
                    if mode == "approval", queue.sync(execute: { !runner.requestList().isEmpty }) { break }
                    if mode == "interrupt", events(mode).contains(where: { $0["state"] as? String == "reviewing" }) {
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.005)
                }
                if mode == "approval" {
                    approvalRequestId = queue.sync { runner.requestList().first?["requestId"] as? String }
                    precondition(approvalRequestId != nil)
                    precondition(
                        queue.sync { runner.respond(requestId: approvalRequestId!, result: ["decision": "accept"]) })
                } else {
                    queue.sync { runner.abort() }
                }
            }
            precondition(finished.wait(timeout: .now() + 5) == .success, mode)
            let values = queue.sync { events(mode) }
            let requests = try String(contentsOf: root.appendingPathComponent(mode + ".jsonl"), encoding: .utf8)
                .split(separator: "\n").map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
            precondition(values.last?["type"] as? String == "exit", mode)
            let sequences = values.compactMap { $0["seq"] as? Int }
            precondition(sequences == sequences.sorted() && Set(sequences).count == sequences.count)
            if mode == "approval" {
                precondition(
                    values.contains {
                        $0["type"] as? String == "request_resolved" && $0["requestId"] as? String == approvalRequestId
                    })
            }
            precondition(!requests.contains { $0["method"] as? String == "turn/start" })
            if ["apikey", "quota", "badprovider"].contains(mode) {
                precondition(!requests.contains { $0["method"] as? String == "review/start" })
                precondition(values.contains { $0["type"] as? String == "error" })
            } else {
                precondition(
                    requests.contains {
                        $0["method"] as? String == "review/start"
                            && ($0["params"] as? [String: Any])?["delivery"] as? String == "inline"
                    })
                precondition(values.filter { $0["state"] as? String == "reviewing" }.count == 1)
                if mode == "account-transition" {
                    precondition(values.contains { $0["type"] as? String == "error" })
                    precondition(
                        requests.filter { $0["method"] as? String == "turn/interrupt" }.count == 1)
                } else if mode == "interrupt" {
                    precondition(values.contains { $0["type"] as? String == "aborted" })
                    precondition(
                        requests.filter { $0["method"] as? String == "turn/interrupt" }.count == 1)
                } else {
                    let reports = values.filter {
                        let content =
                            (($0["event"] as? [String: Any])?["message"] as? [String: Any])?["content"]
                            as? [[String: Any]]
                        return content?.first?["text"] as? String == "Review result"
                    }
                    precondition(reports.count == (mode == "delta" ? 0 : 1), mode)
                    precondition(values.filter { $0["state"] as? String == "review_complete" }.count == 1)
                    if mode == "plan" {
                        let plans = values.compactMap { value -> [String: Any]? in
                            let event = value["event"] as? [String: Any]
                            return event?["type"] as? String == "plan" ? event : nil
                        }
                        precondition(plans.count == 3)
                        precondition(plans[0]["delta"] as? Bool == false && plans[0]["completed"] as? Bool == false)
                        precondition(plans[1]["delta"] as? Bool == true && plans[1]["completed"] as? Bool == false)
                        precondition(plans[2]["delta"] as? Bool == false && plans[2]["completed"] as? Bool == true)
                        precondition(
                            !values.contains {
                                guard let codex = $0["codex"] as? [String: Any], let method = codex["method"] as? String
                                else { return false }
                                return CodexEvent.normalizedMethods.contains(method)
                            })
                    }
                }
                let journal = CodexJournal(sessionId: mode, reset: false)!
                let reader = journal.reader(afterSeq: 0)!
                var replay = Data()
                while let batch = reader.nextBatch() { replay.append(batch) }
                let replayValues = replay.split(separator: 10).map {
                    try! JSONSerialization.jsonObject(with: Data($0)) as! [String: Any]
                }
                let expected = values.filter { ($0["seq"] as? Int ?? 0) > 0 }
                precondition(
                    (try! JSONSerialization.data(withJSONObject: replayValues, options: .sortedKeys))
                        == (try! JSONSerialization.data(withJSONObject: expected, options: .sortedKeys)))
            }
            client.stop()
        }
        for target: [String: Any] in [
            ["type": "uncommittedChanges"], ["type": "baseBranch", "branch": "codex/review"],
            ["type": "commit", "sha": "abcd1234", "title": NSNull()],
            ["type": "custom", "instructions": "Review concurrency\nand persistence."],
        ] {
            precondition(CodexReviewTarget.valid(target))
        }
        for target: [String: Any] in [
            [:], ["type": "unknown"], ["type": "baseBranch", "branch": "--force"],
            ["type": "baseBranch", "branch": "HEAD~1"], ["type": "commit", "sha": "--output=x"],
            ["type": "uncommittedChanges", "extra": true], ["type": "custom", "instructions": " "],
        ] {
            precondition(!CodexReviewTarget.valid(target))
            let head = HTTPRequest.parseHead(Data("POST /sessions/invalid/chat HTTP/1.1\r\n\r\n".utf8))!
            let request = HTTPRequest(
                head: head,
                body: try JSONSerialization.data(withJSONObject: [
                    "provider": "codex", "path": root.path, "prompt": "Review", "reviewTarget": target,
                ]))
            precondition(ChatHandler.start(request, params: ["id": "invalid"]).status == 400)
        }
        let head = HTTPRequest.parseHead(Data("POST /sessions/invalid/chat HTTP/1.1\r\n\r\n".utf8))!
        let claudeRequest = HTTPRequest(
            head: head,
            body: try JSONSerialization.data(withJSONObject: [
                "provider": "claude", "path": root.path, "prompt": "Review",
                "reviewTarget": ["type": "uncommittedChanges"],
            ]))
        precondition(ChatHandler.start(claudeRequest, params: ["id": "invalid"]).status == 400)
        print(
            "Codex review: native fake-process lifecycle, subscription guards, approvals, interruption, report dedup and journal replay passed"
        )
    }
}
