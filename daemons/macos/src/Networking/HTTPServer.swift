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
                Self.receive(on: connection, accumulated: Data())
            }
            listener.start(queue: .global())
            NSLog("HTTPServer: listening on port \(Self.port)")
        } else {
            NSLog("HTTPServer: failed to bind on port \(Self.port)")
        }
    }

    private static let maxRequestBytes = 1_048_576

    private static func receive(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
            var buffer = accumulated
            if let data { buffer.append(data) }

            if let request = HTTPRequest.parse(buffer) {
                let response = Router.handle(request)
                connection.send(content: response.serialize(), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            if buffer.count > maxRequestBytes || isComplete || error != nil {
                connection.cancel()
                return
            }
            receive(on: connection, accumulated: buffer)
        }
    }
}
