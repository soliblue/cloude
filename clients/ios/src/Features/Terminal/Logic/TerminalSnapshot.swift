import Foundation

struct TerminalSnapshot: Decodable, Identifiable {
    let terminalId: String
    let sessionId: String
    let path: String
    let status: String
    let exitCode: Int?
    let error: String?
    let lastSeq: Int
    let createdAt: Double
    let cols: Int
    let rows: Int
    var id: String { terminalId }
    var isRunning: Bool { status == "running" }
    var label: String { Date(timeIntervalSince1970: createdAt / 1000).formatted(date: .omitted, time: .shortened) }
}
