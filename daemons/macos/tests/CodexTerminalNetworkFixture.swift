import Foundation
import Network

final class CodexTerminalNetworkFixture {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "terminal-test.network")
    private var data = Data()
    private var ended = false
    var text: String { queue.sync { String(decoding: data, as: UTF8.self) } }
    var closed: Bool { queue.sync { ended } }

    init(connection: NWConnection) { self.connection = connection }

    func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, complete, error in
            self.queue.sync {
                if let data { self.data.append(data) }
                self.ended = complete || error != nil
            }
            if !complete, error == nil { self.receive() }
        }
    }
}
