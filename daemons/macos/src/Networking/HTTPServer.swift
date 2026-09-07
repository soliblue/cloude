import Foundation
import Network

final class HTTPServer {
    static let port: UInt16 = UInt16(ProcessInfo.processInfo.environment["CLOUDE_PORT"] ?? "8765") ?? 8765
    private var listener: NWListener?

    func start() {
        if let listener = try? NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: Self.port)!) {
            self.listener = listener
            listener.newConnectionHandler = { connection in
                HTTPConnection(connection: connection).start()
            }
            listener.start(queue: .global())
            NSLog("HTTPServer: listening on port \(Self.port)")
        } else {
            NSLog("HTTPServer: failed to bind on port \(Self.port)")
        }
    }

}
