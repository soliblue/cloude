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
            return HTTPResponse.stream { connection in
                RunnerManager.shared.start(
                    sessionId: sessionId, path: path, prompt: prompt, images: images,
                    existsOnServer: existsOnServer, model: model, effort: effort,
                    connection: connection
                )
            }
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }

    static func resume(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"] {
            let afterSeq = Int(request.query["after_seq"] ?? "") ?? -1
            return HTTPResponse.stream { connection in
                let attached = RunnerManager.shared.resumeIfExists(
                    sessionId: sessionId, afterSeq: afterSeq, connection: connection
                )
                if !attached, !SessionJSONLReplay.replay(sessionId: sessionId, to: connection) {
                    connection.cancel()
                }
            }
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }

    static func abort(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"] {
            let aborted = RunnerManager.shared.abort(sessionId: sessionId)
            return HTTPResponse.json(200, ["ok": true, "aborted": aborted])
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }
}
