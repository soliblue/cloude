import Foundation
import Network

@main struct HTTPAdmissionFixture {
    static func main() {
        if CommandLine.arguments.contains("--updating") { _ = DaemonLifecycle.shared.reserveUpdate() }
        let listener = try! NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { HTTPConnection(connection: $0, headerTimeout: 0.3, bodyTimeout: 0.5).start() }
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                print("PORT \(listener.port!.rawValue)")
                fflush(stdout)
            }
        }
        listener.start(queue: .global())
        RunLoop.main.run()
    }
}
