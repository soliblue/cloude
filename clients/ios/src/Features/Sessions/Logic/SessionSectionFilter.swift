import Foundation

enum SessionSectionFilter: Hashable {
    case all
    case unsectioned
    case section(String)

    var query: [String: String] {
        switch self {
        case .all: [:]
        case .unsectioned: ["unsectioned": "true"]
        case .section(let id): ["sectionId": id]
        }
    }
}
