import Foundation
import CloudeShared

enum MemorySource: String, Codable {
    case local
    case project

    var displayName: String {
        switch self {
        case .local: return "Personal"
        case .project: return "Project"
        }
    }

    var iconName: String {
        switch self {
        case .local: return "person.fill"
        case .project: return "folder.fill"
        }
    }
}

struct MemoryItem: Identifiable {
    let id: UUID
    var content: String
    var timestamp: Date?
    var isBullet: Bool

    init(content: String, timestamp: Date? = nil, isBullet: Bool = true) {
        self.id = UUID()
        self.content = content
        self.timestamp = timestamp
        self.isBullet = isBullet
    }
}

struct ParsedMemorySection: Identifiable {
    let id: String
    let title: String
    let items: [MemoryItem]
    let rawContent: String
    var isExpanded: Bool

    init(from section: MemorySection, items: [MemoryItem]) {
        self.id = section.id
        self.title = section.title
        self.items = items
        self.rawContent = section.content
        self.isExpanded = false
    }
}

struct MemoryDocument {
    let source: MemorySource
    var sections: [ParsedMemorySection]

    init(source: MemorySource, sections: [ParsedMemorySection]) {
        self.source = source
        self.sections = sections
    }
}
