import Foundation

final class CodexTerminalRequest<Value> {
    private let group = DispatchGroup()
    private var result: Result<Value, Error>?

    init() { group.enter() }

    func finish(_ result: Result<Value, Error>) {
        self.result = result
        group.leave()
    }

    func wait() -> Result<Value, Error> {
        group.wait()
        return result!
    }
}
