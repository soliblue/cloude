import Foundation

struct DebugEntry: Identifiable {
    let id = UUID()
    let time: Date
    let source: String
    let message: String
}
