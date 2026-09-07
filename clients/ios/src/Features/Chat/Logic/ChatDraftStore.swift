import Foundation

@MainActor
enum ChatDraftStore {
    private static var drafts: [UUID: ChatDraft] = [:]
    private static var revisions: [UUID: Int] = [:]
    private static var edited: [UUID: Set<String>] = [:]
    private static var loaded: Set<UUID> = []

    static func snapshot(for id: UUID) -> ChatDraft { drafts[id] ?? ChatDraft() }
    static func revision(for id: UUID) -> Int { revisions[id, default: 0] }
    static func isLoaded(_ id: UUID) -> Bool { loaded.contains(id) }
    static func references(for id: UUID) -> [ChatReference] { snapshot(for: id).references }
    static func text(for id: UUID) -> String { snapshot(for: id).text }
    static func images(for id: UUID) -> [Data] { snapshot(for: id).images.map(\.data) }
    static func pastedTexts(for id: UUID) -> [String] { snapshot(for: id).pastedTexts }

    static func restore(_ value: ChatDraft, for id: UUID) {
        if !loaded.contains(id) {
            var draft = snapshot(for: id)
            if edited[id]?.contains("text") != true { draft.text = value.text }
            if edited[id]?.contains("references") != true { draft.references = value.references }
            if edited[id]?.contains("images") != true { draft.images = value.images }
            if edited[id]?.contains("pastedTexts") != true { draft.pastedTexts = value.pastedTexts }
            drafts[id] = draft
            loaded.insert(id)
        }
    }

    static func addReference(_ reference: ChatReference, for id: UUID) {
        if !references(for: id).contains(reference) {
            drafts[id, default: ChatDraft()].references.append(reference)
            changed("references", for: id)
        }
    }

    static func setText(_ value: String, for id: UUID) {
        if text(for: id) != value {
            drafts[id, default: ChatDraft()].text = value
            changed("text", for: id)
        }
    }

    static func setImages(_ value: [Data], for id: UUID) {
        if images(for: id) != value {
            var previous = snapshot(for: id).images
            drafts[id, default: ChatDraft()].images = value.map { data in
                if let index = previous.firstIndex(where: { $0.data == data }) { return previous.remove(at: index) }
                return ChatDraftImage(data: data)
            }
            changed("images", for: id)
        }
    }

    static func setPastedTexts(_ value: [String], for id: UUID) {
        if pastedTexts(for: id) != value {
            drafts[id, default: ChatDraft()].pastedTexts = value
            changed("pastedTexts", for: id)
        }
    }

    static func clear(_ id: UUID) {
        drafts[id] = ChatDraft()
        loaded.insert(id)
        revisions[id, default: 0] += 1
        edited[id] = ["text", "references", "images", "pastedTexts"]
    }

    private static func changed(_ field: String, for id: UUID) {
        revisions[id, default: 0] += 1
        edited[id, default: []].insert(field)
    }
}
