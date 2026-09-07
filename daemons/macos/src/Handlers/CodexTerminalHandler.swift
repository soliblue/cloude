import Foundation

enum CodexTerminalHandler {
    static func list(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        guard let sessionId = params["id"], request.query.isEmpty, request.body.isEmpty else { return invalid() }
        return HTTPResponse.json(200, ["terminals": CodexTerminal.shared.list(sessionId: sessionId)])
    }

    static func start(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        guard let sessionId = params["id"], request.query.isEmpty,
            let value = body(request), fields(value, ["requestId", "path", "fullAccess", "rows", "cols"]),
            let requestId = value["requestId"] as? String, UUID(uuidString: requestId) != nil,
            let path = value["path"] as? String, absolutePath(path), value["fullAccess"] as? Bool == true,
            (value["fullAccess"] as? NSNumber).map({ CFGetTypeID($0) == CFBooleanGetTypeID() }) == true,
            let rows = value["rows"] == nil ? 24 : positive(value["rows"], maximum: 1000),
            let cols = value["cols"] == nil ? 80 : positive(value["cols"], maximum: 1000)
        else { return invalid() }
        switch CodexTerminal.shared.start(sessionId: sessionId, requestId: requestId, cwd: path, rows: rows, cols: cols)
        {
        case .success(let value): return HTTPResponse.json(202, value)
        case .failure(let error):
            return HTTPResponse.json((error as NSError).code, ["error": error.localizedDescription])
        }
    }

    static func stream(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        guard let sessionId = params["id"], let terminalId = params["terminalId"], request.body.isEmpty,
            request.query.keys.allSatisfy({ $0 == "after_seq" }), let cursor = cursor(request.query["after_seq"])
        else { return invalid() }
        guard CodexTerminal.shared.stream(sessionId: sessionId, terminalId: terminalId, cursor: cursor) != nil else {
            return HTTPResponse.json(404, ["error": "terminal_not_found"])
        }
        return HTTPResponse.stream(extraHeaders: ["Cache-Control": "no-cache", "X-Accel-Buffering": "no"]) {
            connection in
            CodexTerminalStream(connection: connection, terminalId: terminalId).start(
                sessionId: sessionId, cursor: cursor)
        }
    }

    static func input(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        let close =
            (try? JSONSerialization.jsonObject(with: request.body) as? [String: Any])?["closeStdin"] as? Bool ?? false
        guard let sessionId = params["id"], let terminalId = params["terminalId"], request.query.isEmpty,
            let value = body(request),
            fields(value, ["writerId", "sequence", "deltaBase64", "closeStdin"]),
            let writerId = value["writerId"] as? String,
            UUID(uuidString: writerId) != nil, let sequence = nonnegative(value["sequence"]),
            value["closeStdin"] == nil
                || (value["closeStdin"] as? NSNumber).map({ CFGetTypeID($0) == CFBooleanGetTypeID() }) == true,
            value["deltaBase64"] == nil || value["deltaBase64"] is String,
            let data = value["deltaBase64"] as? String == nil
                ? Data()
                : Data(base64Encoded: value["deltaBase64"] as? String ?? ""),
            data.count <= 64 * 1024, !data.isEmpty || close
        else { return invalid() }
        switch CodexTerminal.shared.input(
            sessionId: sessionId, terminalId: terminalId, writerId: writerId, sequence: sequence, data: data,
            close: close)
        {
        case .success(let duplicate): return HTTPResponse.json(200, ["ok": true, "duplicate": duplicate])
        case .failure(let error):
            return HTTPResponse.json(
                (error as NSError).code, ["error": error.localizedDescription])
        }
    }

    static func resize(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        guard let sessionId = params["id"], let terminalId = params["terminalId"], request.query.isEmpty,
            let value = body(request),
            fields(value, ["rows", "cols"]), let rows = positive(value["rows"], maximum: 1000),
            let cols = positive(value["cols"], maximum: 1000)
        else { return invalid() }
        switch CodexTerminal.shared.resize(sessionId: sessionId, terminalId: terminalId, rows: rows, cols: cols) {
        case .success(let value): return HTTPResponse.json(200, value)
        case .failure(let error):
            return HTTPResponse.json((error as NSError).code, ["error": error.localizedDescription])
        }
    }

    static func terminate(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        guard let sessionId = params["id"], let terminalId = params["terminalId"], request.query.isEmpty,
            request.body.isEmpty
        else { return invalid() }
        switch CodexTerminal.shared.terminate(sessionId: sessionId, terminalId: terminalId) {
        case .success: return HTTPResponse.json(200, ["ok": true])
        case .failure(let error):
            return HTTPResponse.json((error as NSError).code, ["error": error.localizedDescription])
        }
    }

    private static func body(_ request: HTTPRequest) -> [String: Any]? {
        guard request.body.count <= 100_000 else { return nil }
        return try? JSONSerialization.jsonObject(with: request.body) as? [String: Any]
    }

    private static func fields(_ value: [String: Any], _ allowed: [String]) -> Bool {
        value.keys.allSatisfy { allowed.contains($0) }
    }
    private static func absolutePath(_ value: String) -> Bool {
        value.hasPrefix("/") && value.count <= 4096 && !value.contains("\0")
    }
    private static func positive(_ value: Any?, maximum: Int) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFNumberGetTypeID() else { return nil }
        let integer = number.intValue
        return number.doubleValue == Double(integer) && integer >= 1 && integer <= maximum ? integer : nil
    }
    private static func nonnegative(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFNumberGetTypeID(), number.doubleValue.isFinite,
            number.doubleValue >= 0, number.doubleValue <= 9_007_199_254_740_991
        else { return nil }
        return number.doubleValue == Double(number.intValue) ? number.intValue : nil
    }
    private static func cursor(_ value: String?) -> Int? {
        if value == nil { return -1 }
        guard let value, let integer = Int(value), integer >= -1 else { return nil }
        return integer
    }
    private static func invalid() -> HTTPResponse { HTTPResponse.json(400, ["error": "invalid_terminal_request"]) }
}
