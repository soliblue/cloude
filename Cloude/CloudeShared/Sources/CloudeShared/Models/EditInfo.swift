import Foundation

public struct EditInfo: Codable, Equatable, Sendable {
    public let oldString: String
    public let newString: String

    public init(oldString: String, newString: String) {
        self.oldString = oldString
        self.newString = newString
    }

    public func toUnifiedDiff() -> String {
        let oldLines = oldString.components(separatedBy: "\n")
        let newLines = newString.components(separatedBy: "\n")
        var result: [String] = []
        result.append("@@ -1,\(oldLines.count) +1,\(newLines.count) @@")
        for line in oldLines {
            result.append("-\(line)")
        }
        for line in newLines {
            result.append("+\(line)")
        }
        return result.joined(separator: "\n")
    }
}
