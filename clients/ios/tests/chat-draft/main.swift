import Foundation

@main struct DraftTests {
    static func check(_ value: Bool, _ message: String = "Check failed") { precondition(value, message) }

    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = ChatDraftDisk(root: root)
        ChatDraftService.disk = disk
        let id = UUID()
        let image = ChatDraftImage(data: Data(repeating: 37, count: 262_144))
        let saved = ChatDraft(
            text: "Unsent exact 'quotes'\nline",
            references: [ChatReference(name: "README", path: "/work/README", kind: "mention")], images: [image],
            pastedTexts: [String(repeating: "pasted\n", count: 200)])
        try await disk.write(saved, sessionId: id, revision: 0)
        let cold = ChatDraftDisk(root: root)
        let decoded = try await cold.read(id)
        check(decoded == saved, "Fresh disk instance must recover every draft field")
        let imageURL = root.appendingPathComponent(id.uuidString).appendingPathComponent(image.id.uuidString)
        let before = try FileManager.default.attributesOfItem(atPath: imageURL.path)[.modificationDate] as! Date
        var edited = saved
        edited.text = "Only text changed"
        try await disk.write(edited, sessionId: id, revision: 1)
        let after = try FileManager.default.attributesOfItem(atPath: imageURL.path)[.modificationDate] as! Date
        check(before == after, "Text changes must not rewrite image bytes")
        check(try FileManager.default.attributesOfItem(atPath: imageURL.path)[.posixPermissions] as? Int == 0o600)
        let other = UUID()
        check(try await cold.read(other) == nil, "Session scope isolation")
        let hydrated = await ChatDraftService.load(id)
        check(hydrated && ChatDraftStore.snapshot(for: id) == edited, "Cold composer loads all saved content")
        ChatDraftService.setText("Latest edit", for: id)
        await ChatDraftService.flush()
        check(try await cold.read(id)?.text == "Latest edit", "Background flush includes debounce")
        ChatDraftService.clear(id)
        await ChatDraftService.flush()
        try await disk.write(saved, sessionId: id, revision: 1)
        check(try await cold.read(id) == nil, "Late older write cannot resurrect sent draft")
        ChatDraftService.setText("Next message", for: id)
        await ChatDraftService.flush()
        check(try await cold.read(id)?.text == "Next message", "New typing after clear remains durable")
        try await disk.remove(id, revision: 1)
        check(try await cold.read(id)?.text == "Next message", "Late older clear cannot delete new draft")
        ChatDraftService.setImages([image.data], for: id)
        await ChatDraftService.flush()
        let persistedImageId = ChatDraftStore.snapshot(for: id).images[0].id
        ChatDraftService.setImages([], for: id)
        await ChatDraftService.flush()
        check(
            !FileManager.default.fileExists(
                atPath: root.appendingPathComponent(id.uuidString).appendingPathComponent(persistedImageId.uuidString)
                    .path), "Removed attachments are purged after manifest commit")
        let loading = UUID()
        ChatDraftStore.setText("Typed before load finished", for: loading)
        ChatDraftStore.restore(saved, for: loading)
        check(ChatDraftStore.text(for: loading) == "Typed before load finished")
        check(ChatDraftStore.images(for: loading) == [image.data], "Untouched attachments survive concurrent typing")
        let cleared = UUID()
        ChatDraftStore.clear(cleared)
        ChatDraftStore.restore(saved, for: cleared)
        check(ChatDraftStore.snapshot(for: cleared).isEmpty, "In-flight load cannot restore cleared draft")
        let corrupt = UUID()
        let badDirectory = root.appendingPathComponent(corrupt.uuidString)
        try FileManager.default.createDirectory(at: badDirectory, withIntermediateDirectories: true)
        let badManifest = badDirectory.appendingPathComponent("draft.json")
        try Data("broken".utf8).write(to: badManifest)
        check(!(await ChatDraftService.load(corrupt)), "Corrupt draft reports failure")
        ChatDraftService.setText("Keep in memory", for: corrupt)
        await ChatDraftService.flush()
        check(
            try Data(contentsOf: badManifest) == Data("broken".utf8),
            "Unreadable disk draft is not silently overwritten")
        check(SessionToastStore.shared.current?.sessionId == corrupt)
        let failureRoot = root.appendingPathComponent("not-a-directory")
        try Data([1]).write(to: failureRoot)
        ChatDraftService.disk = ChatDraftDisk(root: failureRoot)
        let failure = UUID()
        ChatDraftService.setImages([image.data], for: failure)
        await ChatDraftService.flush()
        check(ChatDraftStore.images(for: failure) == [image.data], "Storage failure keeps attachments in memory")
        check(SessionToastStore.shared.current?.sessionId == failure)
        ChatDraftService.disk = disk
        await ChatDraftService.flush()
        check(
            try await cold.read(failure)?.images.first?.data == image.data, "Failed disk writes retry on the next flush"
        )
        print(
            "PASS durable drafts: cold recovery, attachments untouched by typing, private files, scope isolation, flush, stale write/load/clear fencing, corrupt disk preservation, visible write failure"
        )
    }
}
