import Foundation
import Network

final class HTTPServer {
    static let port: UInt16 = 8765
    private var listener: NWListener?

    func start() {
        if let listener = try? NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: Self.port)!) {
            self.listener = listener
            listener.newConnectionHandler = { connection in
                connection.start(queue: .global())
                Self.readHead(on: connection, accumulated: Data())
            }
            listener.start(queue: .global())
            NSLog("HTTPServer: listening on port \(Self.port)")
        } else {
            NSLog("HTTPServer: failed to bind on port \(Self.port)")
        }
    }

    private static let maxRequestBytes = 16 * 1024 * 1024
    private static let preAuthMaxBodyBytes = 1_048_576

    private static func readHead(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
            var buffer = accumulated
            if let data { buffer.append(data) }

            if let head = HTTPRequest.parseHead(buffer) {
                if head.contentLength > maxRequestBytes {
                    reject(on: connection, response: HTTPResponse.json(413, ["error": "payload_too_large"]))
                    return
                }
                if head.contentLength > preAuthMaxBodyBytes && !AuthMiddleware.isAuthorized(headers: head.headers) {
                    reject(on: connection, response: HTTPResponse.json(401, ["error": "unauthorized"]))
                    return
                }
                let bodySoFar = buffer.subdata(in: head.headerEnd..<buffer.count)
                readBody(on: connection, head: head, body: bodySoFar)
                return
            }

            if buffer.count > maxRequestBytes || isComplete || error != nil {
                connection.cancel()
                return
            }
            readHead(on: connection, accumulated: buffer)
        }
    }

    private static func readBody(on connection: NWConnection, head: HTTPRequest.ParsedHead, body: Data) {
        if body.count >= head.contentLength {
            dispatch(on: connection, request: HTTPRequest(head: head, body: body))
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
            var next = body
            if let data { next.append(data) }
            if next.count > maxRequestBytes {
                reject(on: connection, response: HTTPResponse.json(413, ["error": "payload_too_large"]))
                return
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            readBody(on: connection, head: head, body: next)
        }
    }

    private static func reject(on connection: NWConnection, response: HTTPResponse) {
        connection.send(
            content: response.serialize(),
            completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func dispatch(on connection: NWConnection, request: HTTPRequest) {
        let response = Router.handle(request)
        switch response.body {
        case .streamed(let streamer):
            connection.send(
                content: response.serializeHeaders(),
                completion: .contentProcessed { _ in streamer(connection) })
        case .buffered:
            connection.send(
                content: response.serialize(),
                completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}
