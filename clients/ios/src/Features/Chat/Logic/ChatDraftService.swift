import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum ChatDraftService {
    static var disk = ChatDraftDisk.shared
    private static var loads: [UUID: Task<Bool, Never>] = [:]
    private static var writes: [UUID: Task<Void, Never>] = [:]
    private static var failures: Set<UUID> = []
    private static var unreadable: Set<UUID> = []
    private static var dirty: Set<UUID> = []
    #if canImport(UIKit)
    private static var backgroundGeneration: UUID?
    private static var backgroundToken: UIBackgroundTaskIdentifier = .invalid
    private static var backgroundFlush: Task<Void, Never>?
    #endif

    @discardableResult
    static func load(_ id: UUID) async -> Bool {
        if ChatDraftStore.isLoaded(id) { return !unreadable.contains(id) }
        if let task = loads[id] { return await task.value }
        let task = Task { @MainActor in
            switch await disk.load(id) {
            case .success(let draft):
                ChatDraftStore.restore(draft ?? ChatDraft(), for: id)
                return true
            case .failure:
                if ChatDraftStore.isLoaded(id) { return !unreadable.contains(id) }
                ChatDraftStore.restore(ChatDraft(), for: id)
                unreadable.insert(id)
                reportFailure(id, message: "The saved draft could not be opened. Its files remain on this iPhone.")
                return false
            }
        }
        loads[id] = task
        let result = await task.value
        loads[id] = nil
        return result
    }

    static func setText(_ value: String, for id: UUID) {
        let revision = ChatDraftStore.revision(for: id)
        ChatDraftStore.setText(value, for: id)
        if revision != ChatDraftStore.revision(for: id) { schedule(id) }
    }

    static func setImages(_ value: [Data], for id: UUID) {
        let revision = ChatDraftStore.revision(for: id)
        ChatDraftStore.setImages(value, for: id)
        if revision != ChatDraftStore.revision(for: id) { schedule(id, immediate: true) }
    }

    static func setPastedTexts(_ value: [String], for id: UUID) {
        let revision = ChatDraftStore.revision(for: id)
        ChatDraftStore.setPastedTexts(value, for: id)
        if revision != ChatDraftStore.revision(for: id) { schedule(id) }
    }

    static func addReference(_ value: ChatReference, for id: UUID) {
        let revision = ChatDraftStore.revision(for: id)
        ChatDraftStore.addReference(value, for: id)
        if revision != ChatDraftStore.revision(for: id) { schedule(id) }
    }

    static func clear(_ id: UUID) {
        ChatDraftStore.clear(id)
        failures.remove(id)
        unreadable.remove(id)
        schedule(id, immediate: true)
    }

    static func flush() async {
        let ids = Array(dirty)
        for id in ids { writes[id]?.cancel() }
        for id in ids { await persist(id) }
    }

    static func flushForBackground() {
        #if canImport(UIKit)
        if backgroundGeneration == nil && !dirty.isEmpty {
            let generation = UUID()
            backgroundGeneration = generation
            backgroundToken = UIApplication.shared.beginBackgroundTask(withName: "Save drafts") {
                Task { @MainActor in finishBackground(generation, expired: true) }
            }
            backgroundFlush = Task {
                await flush()
                finishBackground(generation)
            }
        }
        #else
        Task { await flush() }
        #endif
    }

    #if canImport(UIKit)
    private static func finishBackground(_ generation: UUID, expired: Bool = false) {
        if backgroundGeneration == generation {
            if expired { backgroundFlush?.cancel() }
            backgroundFlush = nil
            backgroundGeneration = nil
            let token = backgroundToken
            backgroundToken = .invalid
            if token != .invalid { UIApplication.shared.endBackgroundTask(token) }
        }
    }
    #endif

    private static func schedule(_ id: UUID, immediate: Bool = false) {
        dirty.insert(id)
        writes[id]?.cancel()
        writes[id] = Task {
            if !immediate { try? await Task.sleep(for: .milliseconds(200)) }
            if !Task.isCancelled { await persist(id) }
        }
    }

    private static func persist(_ id: UUID) async {
        let loaded = await load(id)
        if loaded && !Task.isCancelled {
            let revision = ChatDraftStore.revision(for: id)
            let draft = ChatDraftStore.snapshot(for: id)
            switch await disk.save(draft, sessionId: id, revision: revision) {
            case .success:
                if revision == ChatDraftStore.revision(for: id) {
                    dirty.remove(id)
                    failures.remove(id)
                }
            case .failure:
                reportFailure(
                    id,
                    message:
                        "This draft is still open, but could not be saved on this iPhone. Keep the app open and free some storage before closing it."
                )
            }
        }
    }

    private static func reportFailure(_ id: UUID, message: String) {
        if failures.insert(id).inserted {
            SessionToastStore.shared.present(
                SessionToast(
                    sessionId: id, title: "Draft not saved", symbol: "exclamationmark.triangle.fill", snippet: message))
        }
    }
}
