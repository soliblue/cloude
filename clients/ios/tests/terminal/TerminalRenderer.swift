import Foundation

@MainActor final class TerminalRenderer {
    var onInput: (Data) -> Void = { _ in }
    var onResize: (Int, Int) -> Void = { _, _ in }
    var bytes = Data()
    var responsePermissions: [Bool] = []
    var resets = 0
    var closed = false
    var cols: Int
    var rows: Int
    init(cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
    }
    func feed(_ data: Data, allowResponses: Bool) {
        bytes.append(data)
        responsePermissions.append(allowResponses)
    }
    func reset() {
        bytes = Data()
        resets += 1
    }
    func fitToViewport() {}
    func resize(cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
    }
    func close() { closed = true }
}
