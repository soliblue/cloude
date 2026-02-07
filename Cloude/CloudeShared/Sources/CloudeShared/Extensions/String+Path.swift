import Foundation

public extension String {
    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }

    var pathExtension: String {
        (self as NSString).pathExtension
    }

    var deletingPathExtension: String {
        (self as NSString).deletingPathExtension
    }

    var deletingLastPathComponent: String {
        (self as NSString).deletingLastPathComponent
    }

    var expandingTildeInPath: String {
        (self as NSString).expandingTildeInPath
    }

    func appendingPathComponent(_ str: String) -> String {
        (self as NSString).appendingPathComponent(str)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
