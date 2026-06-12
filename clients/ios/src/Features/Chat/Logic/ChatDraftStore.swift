import Foundation

@MainActor
enum ChatDraftStore {
    private static var texts: [UUID: String] = [:]
    private static var imagesById: [UUID: [Data]] = [:]
    private static var pastedTextsById: [UUID: [String]] = [:]

    static func text(for sessionId: UUID) -> String { texts[sessionId] ?? "" }
    static func images(for sessionId: UUID) -> [Data] { imagesById[sessionId] ?? [] }
    static func pastedTexts(for sessionId: UUID) -> [String] { pastedTextsById[sessionId] ?? [] }

    static func setText(_ value: String, for sessionId: UUID) {
        texts[sessionId] = value.isEmpty ? nil : value
    }

    static func setImages(_ value: [Data], for sessionId: UUID) {
        imagesById[sessionId] = value.isEmpty ? nil : value
    }

    static func setPastedTexts(_ value: [String], for sessionId: UUID) {
        pastedTextsById[sessionId] = value.isEmpty ? nil : value
    }
}
