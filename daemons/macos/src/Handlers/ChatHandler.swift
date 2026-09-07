import Foundation
import Network

enum ChatHandler {
    static func start(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"],
            let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
            let path = body["path"] as? String,
            let prompt = body["prompt"] as? String
        {
            let images = (body["images"] as? [[String: String]]) ?? []
            let existsOnServer = (body["existsOnServer"] as? Bool) ?? false
            let model = body["model"] as? String
            let effort = body["effort"] as? String
            let permissionMode = body["permissionMode"] as? String
            let provider = body["provider"] as? String
            let threadId = body["threadId"] as? String
            if let reviewTarget = body["reviewTarget"], provider != "codex" || !CodexReviewTarget.valid(reviewTarget) {
                return HTTPResponse.json(
                    400,
                    ["error": "Provide a valid Codex review target: uncommittedChanges, baseBranch, commit, or custom."]
                )
            }
            if let shellCommand = body["shellCommand"],
                provider != "codex" || !CodexShellCommand.valid(shellCommand)
                    || body["reviewTarget"] != nil || !images.isEmpty
                    || !(body["skills"] as? [[String: String]] ?? []).isEmpty
                    || !(body["mentions"] as? [[String: String]] ?? []).isEmpty
            {
                return HTTPResponse.json(
                    400, ["error": "Provide one Codex command without images, references or a review target."])
            }
            if provider == "codex", let id = threadId ?? CodexSessionStore.shared.threadId(for: sessionId),
                CodexClient.shared.isThreadActive(threadId: id)
            {
                return HTTPResponse.json(
                    409, ["error": "This task is running on the host. Wait for it to finish before continuing."])
            }
            if CodexHandler.isMutating(sessionId) || RunnerManager.shared.isRunning(sessionId: sessionId) {
                return HTTPResponse.json(409, ["error": "session_already_running"])
            }
            if let provider, !["codex", "claude"].contains(provider) {
                return HTTPResponse.json(400, ["error": "unknown_provider"])
            }
            #if DEBUG
            NSLog(
                "[ChatHandler] start sessionId=\(sessionId) path=\(path) existsOnServer=\(existsOnServer) model=\(model ?? "nil") effort=\(effort ?? "nil") permissionMode=\(permissionMode ?? "nil") promptChars=\(prompt.count) images=\(images.count)"
            )
            #endif
            return HTTPResponse.stream { connection in
                RunnerManager.shared.start(
                    sessionId: sessionId, path: path, prompt: prompt, images: images,
                    existsOnServer: existsOnServer, model: model, effort: effort,
                    permissionMode: permissionMode, provider: provider, threadId: threadId,
                    skills: body["skills"] as? [[String: String]] ?? [],
                    mentions: body["mentions"] as? [[String: String]] ?? [],
                    projectId: body["projectId"] as? String,
                    reviewTarget: body["reviewTarget"] as? [String: Any],
                    shellCommand: body["shellCommand"] as? String,
                    connection: connection
                )
            }
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }

    static func resume(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"] {
            let afterSeq = Int(request.query["after_seq"] ?? "") ?? -1
            #if DEBUG
            NSLog("[ChatHandler] resume sessionId=\(sessionId) afterSeq=\(afterSeq)")
            #endif
            return HTTPResponse.stream { connection in
                let attached = RunnerManager.shared.resumeIfExists(
                    sessionId: sessionId, afterSeq: afterSeq, connection: connection
                )
                if !attached,
                    !CodexJournalReplay.resume(sessionId: sessionId, afterSeq: afterSeq, connection: connection),
                    !SessionJSONLReplay.replay(sessionId: sessionId, to: connection)
                {
                    connection.cancel()
                }
            }
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }

    static func abort(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"] {
            #if DEBUG
            NSLog("[ChatHandler] abort sessionId=\(sessionId)")
            #endif
            if RunnerManager.shared.abort(sessionId: sessionId) {
                return HTTPResponse.json(200, ["ok": true, "aborted": true])
            }
            return CodexControlHandler.abort(sessionId: sessionId)
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }

    static func steer(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        guard request.body.count <= 262_144, request.query.isEmpty,
            let sessionId = params["id"],
            let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
            body.keys.allSatisfy({ ["prompt", "requestId"].contains($0) }),
            let prompt = body["prompt"] as? String, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            prompt.utf16.count <= 32_768,
            body["requestId"] == nil || (body["requestId"] as? String).flatMap(UUID.init(uuidString:)) != nil
        else { return HTTPResponse.json(400, ["error": "invalid_steering_request"]) }
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[String: Any], Error>?
        if RunnerManager.shared.steer(
            sessionId: sessionId, prompt: prompt, requestId: body["requestId"] as? String,
            completion: { response in
                result = response
                semaphore.signal()
            })
        {
            if semaphore.wait(timeout: .now() + 21) == .success, let result {
                switch result {
                case .success: return HTTPResponse.json(200, ["ok": true])
                case .failure(let error):
                    return HTTPResponse.json(
                        [402, 409, 503].contains((error as NSError).code) ? (error as NSError).code : 502,
                        ["error": error.localizedDescription])
                }
            }
            return HTTPResponse.json(504, ["error": "Codex did not confirm the steering message."])
        }
        return HTTPResponse.json(409, ["error": "no_active_codex_turn"])
    }

    static func respond(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"],
            let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
            let requestId = body["requestId"] as? String,
            let result = body["result"] as? [String: Any]
        {
            let responded = RunnerManager.shared.respond(sessionId: sessionId, requestId: requestId, result: result)
            return HTTPResponse.json(responded ? 200 : 404, ["ok": responded])
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }

    static func requests(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"] {
            return HTTPResponse.json(
                200,
                [
                    "requests": RunnerManager.shared.requests(sessionId: sessionId),
                    "agentAttention": RunnerManager.shared.agentAttention(sessionId: sessionId),
                ])
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }
}
