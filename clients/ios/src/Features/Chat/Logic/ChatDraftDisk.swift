import Foundation

actor ChatDraftDisk {
    static let shared = ChatDraftDisk()
    private let root: URL
    private var revisions: [UUID: Int] = [:]

    init(
        root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChatDrafts")
    ) {
        self.root = root
    }

    func load(_ sessionId: UUID) -> Result<ChatDraft?, Error> {
        Result { try read(sessionId) }
    }

    func save(_ draft: ChatDraft, sessionId: UUID, revision: Int) -> Result<Void, Error> {
        Result {
            if draft.isEmpty {
                try remove(sessionId, revision: revision)
            } else {
                try write(draft, sessionId: sessionId, revision: revision)
            }
        }
    }

    func read(_ sessionId: UUID) throws -> ChatDraft? {
        let directory = root.appendingPathComponent(sessionId.uuidString)
        let manifest = directory.appendingPathComponent("draft.json")
        if FileManager.default.fileExists(atPath: manifest.path) {
            let record = try JSONDecoder().decode(ChatDraftRecord.self, from: Data(contentsOf: manifest))
            if record.version != 1 { throw CocoaError(.fileReadCorruptFile) }
            return ChatDraft(
                text: record.text, references: record.references,
                images: try record.images.map {
                    ChatDraftImage(id: $0, data: try Data(contentsOf: directory.appendingPathComponent($0.uuidString)))
                },
                pastedTexts: record.pastedTexts)
        }
        return nil
    }

    func write(_ draft: ChatDraft, sessionId: UUID, revision: Int) throws {
        if revision >= revisions[sessionId, default: -1] {
            revisions[sessionId] = revision
            let directory = root.appendingPathComponent(sessionId.uuidString)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
            for image in draft.images {
                let url = directory.appendingPathComponent(image.id.uuidString)
                if !FileManager.default.fileExists(atPath: url.path) { try writePrivate(image.data, to: url) }
            }
            try writePrivate(
                JSONEncoder().encode(
                    ChatDraftRecord(
                        text: draft.text, references: draft.references,
                        images: draft.images.map(\.id), pastedTexts: draft.pastedTexts)),
                to: directory.appendingPathComponent("draft.json"))
            let retained = Set(draft.images.map { $0.id.uuidString } + ["draft.json"])
            for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                if !retained.contains(url.lastPathComponent) { try? FileManager.default.removeItem(at: url) }
            }
        }
    }

    func remove(_ sessionId: UUID, revision: Int) throws {
        if revision >= revisions[sessionId, default: -1] {
            revisions[sessionId] = revision
            let directory = root.appendingPathComponent(sessionId.uuidString)
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        }
    }

    private func writePrivate(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
