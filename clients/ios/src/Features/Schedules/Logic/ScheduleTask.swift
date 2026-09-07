import Foundation

struct ScheduleTask: Codable {
    var provider = "codex"
    var path: String
    var prompt: String
    var model: String?
    var effort: String?
    var permissionMode = "default"
}
