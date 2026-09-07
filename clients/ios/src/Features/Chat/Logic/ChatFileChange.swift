import Foundation

nonisolated struct ChatFileChange: Identifiable {
    let path: String
    let kind: String
    let movedPath: String?
    let diff: String

    var id: String { path }
    var title: String {
        movedPath == nil ? ["add": "Added", "delete": "Deleted", "update": "Updated"][kind] ?? "Changed" : "Renamed"
    }
    var symbol: String { ["add": "plus.circle", "delete": "minus.circle"][kind] ?? "pencil.circle" }

    init?(_ value: [String: Any]) {
        if let path = value["path"] as? String, let diff = value["diff"] as? String {
            self.path = path
            self.diff = diff
            self.kind = (value["kind"] as? [String: Any])?["type"] as? String ?? value["kind"] as? String ?? "update"
            self.movedPath = (value["kind"] as? [String: Any])?["move_path"] as? String
        } else {
            return nil
        }
    }
}
