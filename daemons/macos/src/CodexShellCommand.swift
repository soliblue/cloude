import Foundation

nonisolated enum CodexShellCommand {
    static func valid(_ value: Any?) -> Bool {
        (value as? String).map {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf16.count <= 16384 && !$0.contains("\0")
        } == true
    }
}
