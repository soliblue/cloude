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
            return HTTPResponse.stream { connection in
                RunnerManager.shared.start(
                    sessionId: sessionId, path: path, prompt: prompt, images: images,
                    existsOnServer: existsOnServer, connection: connection
                )
            }
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }

    static func resume(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"] {
            if !RunnerManager.shared.hasRunner(sessionId: sessionId) {
                return HTTPResponse.json(404, ["error": "no_session"])
            }
            let afterSeq = Int(request.query["after_seq"] ?? "") ?? -1
            return HTTPResponse.stream { connection in
                RunnerManager.shared.resume(
                    sessionId: sessionId, afterSeq: afterSeq, connection: connection
                )
            }
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }

    static func abort(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"] {
            let ok = RunnerManager.shared.abort(sessionId: sessionId)
            return HTTPResponse.json(ok ? 200 : 404, ["ok": ok])
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }
}
