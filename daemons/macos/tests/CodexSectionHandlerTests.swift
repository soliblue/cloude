import Foundation

struct CodexSessionStore {
    static let shared = CodexSessionStore()
    func threadId(for sessionId: String) -> String? { sessionId == "session-1" ? "thread-1" : nil }
}

enum CodexHandler {
    static var transport: (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void = {
        _, _, callback in callback(.success(["ok": true]))
    }
}

@main
struct CodexSectionHandlerTests {
    static func request(_ method: String, query: [String: String] = [:], body: Any? = nil) -> HTTPRequest {
        let head = HTTPRequest.ParsedHead(
            method: method, path: "/fixture", query: query, headers: [:], headerEnd: 0, contentLength: 0)
        return HTTPRequest(head: head, body: body.flatMap { try? JSONSerialization.data(withJSONObject: $0) } ?? Data())
    }

    static func main() {
        var calls: [(String, [String: Any])] = []
        CodexHandler.transport = { method, params, callback in
            calls.append((method, params))
            callback(.success(["data": [], "nextCursor": NSNull()]))
        }
        precondition(
            CodexSectionHandler.sections(request("GET", query: ["limit": "7", "cursor": "next"])).status == 200)
        precondition(calls.last?.0 == "threadSection/list")
        precondition(calls.last?.1["limit"] as? Int == 7 && calls.last?.1["cursor"] as? String == "next")
        precondition(
            CodexSectionHandler.sections(request("POST", body: ["name": "  Work  ", "appearance": ["color": "blue"]]))
                .status == 200)
        precondition(calls.last?.0 == "threadSection/create" && calls.last?.1["name"] as? String == "Work")
        precondition(
            CodexSectionHandler.update(request("POST", body: ["name": "Renamed"]), params: ["id": "section-1"]).status
                == 200)
        precondition(calls.last?.0 == "threadSection/update" && calls.last?.1["sectionId"] as? String == "section-1")
        precondition(CodexSectionHandler.delete(request("DELETE"), params: ["id": "section-1"]).status == 200)
        precondition(calls.last?.0 == "threadSection/delete")
        precondition(
            CodexSectionHandler.move(
                request("POST", body: ["sectionId": NSNull(), "beforeThreadId": "thread-2"]),
                params: ["id": "session-1"]
            ).status == 200)
        precondition(calls.last?.0 == "thread/section/move" && calls.last?.1["threadId"] as? String == "thread-1")
        precondition(
            CodexSectionHandler.threads(request("GET", query: ["limit": "9"]), params: ["id": "section-1"]).status
                == 200)
        precondition(
            calls.last?.0 == "thread/list"
                && calls.last?.1["sortKey"] as? String == "section_position"
                && (calls.last?.1["sourceKinds"] as? [String])?.contains("subAgentThreadSpawn") == true)
        for invalid in [
            request("GET", query: ["limit": "+1"]), request("GET", query: ["limit": "01"]),
            request("POST", body: ["name": " "]), request("POST", body: ["name": "name", "extra": true]),
            request("POST", body: ["name": String(repeating: "x", count: 20_000)]),
        ] { precondition(CodexSectionHandler.sections(invalid).status == 400) }
        precondition(CodexSectionHandler.threads(request("GET"), params: ["id": "../escape"]).status == 400)
        precondition(
            CodexSectionHandler.move(
                request("POST", body: ["sectionId": "section/escape"]), params: ["id": "session-1"]
            ).status == 400)
        precondition(
            CodexSectionHandler.delete(request("DELETE", body: ["extra": true]), params: ["id": "section-1"]).status
                == 400)
        print("Codex sections: strict CRUD, pagination, move mapping and malformed input validation passed")
    }
}
