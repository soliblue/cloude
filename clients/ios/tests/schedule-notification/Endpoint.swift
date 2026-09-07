import Foundation

final class Endpoint {
    var id = UUID()
    var capabilities: [String]? = ["agentSchedules"]
    var revision = UUID()
}
