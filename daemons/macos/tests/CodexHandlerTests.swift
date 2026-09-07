import Foundation

@main
struct CodexHandlerTests {
    static func request(
        _ method: String = "GET", body: Any = [:], query: [String: String] = [:], headers: [String: String] = [:]
    ) -> HTTPRequest {
        HTTPRequest(
            head: HTTPRequest.ParsedHead(
                method: method, path: "/fixture", query: query, headers: headers, headerEnd: 0),
            body: try! JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed]))
    }

    static func json(_ response: HTTPResponse) -> [String: Any] {
        if case .buffered(let data) = response.body {
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        }
        return [:]
    }

    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "afto-codex-handler-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        setenv("CLOUDE_DATA", root.path, 1)
        var calls: [(String, [String: Any])] = []
        var text = "first"
        CodexHandler.transport = { method, params, callback in
            calls.append((method, params))
            if method == "skills/list" {
                callback(
                    .success([
                        "data": [
                            [
                                "skills": [
                                    ["name": "enabled", "path": "/skills/enabled/SKILL.md", "enabled": true],
                                    ["name": "disabled", "path": "/skills/disabled/SKILL.md", "enabled": false],
                                ]
                            ]
                        ]
                    ]))
            } else if ["thread/read", "thread/fork"].contains(method) {
                callback(
                    .success([
                        "thread": [
                            "id": method == "thread/fork" ? "fork-thread" : "source-thread", "cwd": root.path,
                            "turns": [["text": text]],
                        ]
                    ]))
            } else {
                callback(.success(["ok": true]))
            }
        }
        precondition(CodexHandler.threads(request()).status == 200)
        precondition(calls.last?.1["useStateDbOnly"] as? Bool == true)
        precondition(CodexHandler.threads(request(query: ["refresh": "true", "cursor": "cursor"])).status == 200)
        precondition(calls.last?.1["useStateDbOnly"] as? Bool == false)
        precondition(calls.last?.1["cursor"] as? String == "cursor")
        precondition(CodexHandler.skills(request(query: ["path": root.path, "reload": "true"])).status == 200)
        precondition(calls.last?.1["cwds"] as? [String] == [root.path])
        precondition(calls.last?.1["forceReload"] as? Bool == true)
        let manifest = json(CodexHandler.manifest(request(query: ["path": root.path])))
        precondition((manifest["skills"] as? [[String: String]])?.map { $0["name"] } == ["enabled"])
        precondition(CodexHandler.modes(request()).status == 200)
        precondition(calls.last?.0 == "collaborationMode/list")
        precondition(CodexHandler.projects(request(query: ["cursor": "next"])).status == 200)
        precondition(calls.last?.0 == "project/list")
        precondition(
            CodexHandler.createProject(request("POST", body: ["name": "Example", "roots": [["path": root.path]]]))
                .status == 200)
        precondition(calls.last?.0 == "project/create")
        precondition(
            CodexHandler.createProject(request("POST", body: ["name": "Example", "roots": [["path": "relative"]]]))
                .status == 400)

        let params = ["id": "source-session"]
        precondition(
            CodexHandler.importThread(request("POST", body: ["threadId": "source-thread"]), params: params).status
                == 200)
        precondition(CodexSessionStore.shared.threadId(for: "SOURCE-SESSION") == "source-thread")
        let history = CodexHandler.history(request(), params: params)
        precondition(history.status == 200)
        let etag = history.extraHeaders["ETag"]!
        precondition(CodexHandler.history(request(headers: ["if-none-match": etag]), params: params).status == 304)
        text = "changed"
        precondition(CodexHandler.history(request(headers: ["if-none-match": etag]), params: params).status == 200)
        precondition(CodexHandler.rename(request("POST", body: ["name": "  New name  "]), params: params).status == 200)
        precondition(calls.last?.1["name"] as? String == "New name")
        precondition(calls.last?.1["threadId"] as? String == "source-thread")
        precondition(CodexHandler.rename(request("POST", body: ["name": " "]), params: params).status == 400)

        precondition(
            CodexHandler.fork(request("POST", body: ["newSessionId": "fork-session"]), params: params).status == 200)
        let beforeConflict = calls.count
        precondition(
            CodexHandler.fork(request("POST", body: ["newSessionId": "fork-session"]), params: params).status == 409)
        precondition(calls.count == beforeConflict)
        RunnerManager.shared.active = ["source-session"]
        precondition(
            CodexHandler.importThread(request("POST", body: ["threadId": "other"]), params: params).status == 409)
        precondition(CodexHandler.fork(request("POST", body: ["newSessionId": "other"]), params: params).status == 409)
        precondition(calls.count == beforeConflict)
        RunnerManager.shared.active = []
        precondition(CodexHandler.archive(request("POST", body: ["archived": false]), params: params).status == 200)
        precondition(calls.last?.0 == "thread/unarchive")
        precondition(CodexHandler.archive(request("POST", body: ["archived": 1]), params: params).status == 400)

        precondition(
            CodexHandler.goal(
                request("POST", body: ["objective": "Finish", "tokenBudget": 1000, "status": "paused"]), params: params
            ).status == 200)
        precondition(calls.last?.0 == "thread/goal/set")
        precondition(calls.last?.1["tokenBudget"] as? Int == 1000)
        precondition(CodexHandler.goal(request("POST", body: ["tokenBudget": NSNull()]), params: params).status == 200)
        precondition(calls.last?.1["tokenBudget"] is NSNull)
        for invalid in [
            [:], ["objective": ""], ["tokenBudget": true], ["tokenBudget": 1.5], ["tokenBudget": -1],
            ["status": "invented"],
        ] as [[String: Any]] {
            precondition(CodexHandler.goal(request("POST", body: invalid), params: params).status == 400)
        }
        precondition(CodexHandler.goal(request(), params: params).status == 200)
        precondition(calls.last?.0 == "thread/goal/get")
        precondition(CodexHandler.goal(request("DELETE"), params: params).status == 200)
        precondition(calls.last?.0 == "thread/goal/clear")
        for invalid in [NSNull(), [], "string"] as [Any] {
            precondition(CodexHandler.fork(request("POST", body: invalid), params: params).status == 400)
            precondition(CodexHandler.importThread(request("POST", body: invalid), params: params).status == 400)
            precondition(CodexHandler.archive(request("POST", body: invalid), params: params).status == 400)
        }
        var loginStartCount = 0
        var cancelCount = 0
        var pendingLoginReply: ((Result<[String: Any], Error>) -> Void)?
        var pendingCancelReply: ((Result<[String: Any], Error>) -> Void)?
        var cancelIds: [String] = []
        CodexLoginService.shared.resetForTesting()
        CodexLoginService.request = { method, params, callback in
            if method == "account/login/start" {
                loginStartCount += 1
                pendingLoginReply = callback
            } else if method == "account/login/cancel" {
                cancelCount += 1
                cancelIds.append(params["loginId"] as? String ?? "")
                pendingCancelReply = callback
            }
        }
        precondition(CodexHandler.login(request("POST")).status == 200)
        precondition(CodexHandler.login(request("POST", body: ["type": "chatgptDeviceCode"])).status == 200)
        precondition(loginStartCount == 1)
        CodexLoginService.shared.notification([
            "method": "account/login/completed", "params": ["success": true, "loginId": "early-login"],
        ])
        CodexLoginService.shared.notification([
            "method": "account/login/completed", "params": ["success": true],
        ])
        pendingLoginReply?(
            .success([
                "type": "chatgptDeviceCode", "loginId": "early-login", "userCode": "ABCD",
                "verificationUrl": "https://auth.openai.com/codex/device",
            ]))
        precondition((json(CodexHandler.login(request()))["status"] as? String) == "completed")
        precondition(json(CodexHandler.login(request()))["userCode"] == nil)
        precondition(CodexHandler.login(request("POST", body: ["type": "apiKey"])).status == 400)
        precondition(
            CodexHandler.login(request("POST", body: ["type": "chatgptDeviceCode", "apiKey": "secret"])).status == 400)

        CodexLoginService.shared.resetForTesting()
        pendingLoginReply = nil
        precondition(CodexHandler.login(request("POST")).status == 200)
        pendingLoginReply?(
            .success([
                "type": "chatgptDeviceCode", "loginId": "bad-url", "userCode": "ABCD",
                "verificationUrl": "https://auth.openai.com.evil.invalid/codex/device",
            ]))
        precondition((json(CodexHandler.login(request()))["status"] as? String) == "failed")

        CodexLoginService.shared.resetForTesting()
        pendingLoginReply = nil
        cancelCount = 0
        precondition(CodexHandler.login(request("POST")).status == 200)
        precondition(CodexHandler.login(request("DELETE")).status == 200)
        pendingLoginReply?(
            .success([
                "type": "chatgptDeviceCode", "loginId": "login-canceled", "userCode": "EFGH",
                "verificationUrl": "https://auth.openai.com/codex/device",
            ]))
        precondition(cancelCount == 1)
        precondition(cancelIds == ["login-canceled"])
        precondition((json(CodexHandler.login(request()))["status"] as? String) == "pending")
        precondition(json(CodexHandler.login(request()))["userCode"] as? String == "EFGH")
        precondition(CodexHandler.login(request("DELETE")).status == 200)
        precondition(cancelCount == 1)
        pendingCancelReply?(.failure(NSError(domain: "fixture", code: 1)))
        precondition(CodexHandler.login(request("DELETE")).status == 502)
        precondition((json(CodexHandler.login(request()))["status"] as? String) == "pending")
        precondition(
            (json(CodexHandler.login(request()))["error"] as? String) == "Could not cancel sign-in. Try again.")
        precondition(CodexHandler.login(request("DELETE")).status == 502)
        pendingCancelReply?(.success(["status": "canceled"]))
        precondition((json(CodexHandler.login(request()))["status"] as? String) == "canceled")
        precondition(json(CodexHandler.login(request()))["userCode"] == nil)
        precondition(json(CodexHandler.login(request()))["verificationUrl"] == nil)

        CodexLoginService.shared.resetForTesting()
        pendingLoginReply = nil
        pendingCancelReply = nil
        precondition(CodexHandler.login(request("POST")).status == 200)
        pendingLoginReply?(
            .success([
                "type": "chatgptDeviceCode", "loginId": "login-failed-cancel", "userCode": "IJKL",
                "verificationUrl": "https://auth.openai.com/codex/device",
            ]))
        precondition(CodexHandler.login(request("DELETE")).status == 200)
        CodexLoginService.shared.notification([
            "method": "account/login/completed", "params": ["success": false, "loginId": "login-failed-cancel"],
        ])
        precondition((json(CodexHandler.login(request()))["status"] as? String) == "pending")
        pendingCancelReply?(.failure(NSError(domain: "fixture", code: 2)))
        precondition((json(CodexHandler.login(request()))["status"] as? String) == "failed")
        precondition(json(CodexHandler.login(request()))["userCode"] == nil)

        CodexLoginService.shared.resetForTesting()
        pendingLoginReply = nil
        pendingCancelReply = nil
        precondition(CodexHandler.login(request("POST")).status == 200)
        pendingLoginReply?(
            .success([
                "type": "chatgptDeviceCode", "loginId": "login-success-cancel", "userCode": "MNOP",
                "verificationUrl": "https://auth.openai.com/codex/device",
            ]))
        precondition(CodexHandler.login(request("DELETE")).status == 200)
        CodexLoginService.shared.notification([
            "method": "account/login/completed", "params": ["success": true, "loginId": "login-success-cancel"],
        ])
        pendingCancelReply?(.failure(NSError(domain: "fixture", code: 3)))
        precondition((json(CodexHandler.login(request()))["status"] as? String) == "completed")

        CodexLoginService.shared.resetForTesting()
        pendingLoginReply = nil
        precondition(CodexHandler.login(request("POST")).status == 200)
        pendingLoginReply?(.success(["type": "apiKey", "apiKey": "secret"]))
        precondition((json(CodexHandler.login(request()))["status"] as? String) == "failed")
        precondition(
            json(CodexHandler.login(request()))["error"] as? String
                == "Codex did not return a supported ChatGPT device-code sign-in.")
        CodexLoginService.shared.resetForTesting()
        pendingLoginReply = nil
        precondition(CodexHandler.login(request("POST")).status == 200)
        CodexLoginService.shared.disconnected(
            NSError(domain: "fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "private token"]))
        precondition((json(CodexHandler.login(request()))["status"] as? String) == "failed")
        precondition(
            json(CodexHandler.login(request()))["error"] as? String
                == "Codex disconnected during sign-in. Start a new device code.")
        let entered = DispatchSemaphore(value: 0)
        let allowReply = DispatchSemaphore(value: 0)
        let completed = DispatchSemaphore(value: 0)
        var firstStatus = 0
        CodexHandler.transport = { method, _, callback in
            if method == "thread/read" {
                callback(.success(["thread": ["id": "source-thread", "cwd": root.path]]))
            } else {
                entered.signal()
                precondition(allowReply.wait(timeout: .now() + 3) == .success)
                callback(.success(["thread": ["id": "concurrent-thread", "cwd": root.path]]))
            }
        }
        DispatchQueue.global().async {
            firstStatus =
                CodexHandler.fork(request("POST", body: ["newSessionId": "concurrent-session"]), params: params).status
            completed.signal()
        }
        precondition(entered.wait(timeout: .now() + 3) == .success)
        precondition(
            CodexHandler.fork(request("POST", body: ["newSessionId": "CONCURRENT-SESSION"]), params: params).status
                == 409)
        allowReply.signal()
        precondition(completed.wait(timeout: .now() + 3) == .success)
        precondition(firstStatus == 200)

        CodexHandler.transport = { _, _, callback in
            callback(
                .failure(
                    NSError(
                        domain: "fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Codex auth needs attention"])
                ))
        }
        let failure = CodexHandler.models(request())
        precondition(failure.status == 502)
        precondition(json(failure)["message"] as? String == "Codex auth needs attention")
        precondition(CodexHandler.perform("model/list", params: [:]) == nil)
        print(
            "Codex native handlers: controls, validation, active conflicts, ETag changes, manifest filtering and RPC errors passed"
        )
    }
}
