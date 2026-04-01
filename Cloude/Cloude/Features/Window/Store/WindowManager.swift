import Foundation
import Combine
import CloudeShared

@MainActor
class WindowManager: ObservableObject {
    @Published var windows: [Window] = [Window()]
    @Published var activeWindowId: UUID?

    var fileTreeStates: [UUID: FileTreeState] = [:]
    var gitChangesStates: [UUID: GitChangesState] = [:]

    private let windowsKey = "windowManager_windows"
    private let activeKey = "windowManager_activeWindowId"

    init() {
        load()
        if windows.isEmpty {
            windows = [Window()]
        }
        if activeWindowId == nil {
            activeWindowId = windows.first?.id
        }
    }

    private func save() {
        UserDefaults.standard.setCodable(windows, forKey: windowsKey)
        if let activeId = activeWindowId {
            UserDefaults.standard.set(activeId.uuidString, forKey: activeKey)
        }
    }

    private func load() {
        windows = UserDefaults.standard.codable([Window].self, forKey: windowsKey, default: [])
        if let idString = UserDefaults.standard.string(forKey: activeKey),
           let id = UUID(uuidString: idString),
           windows.contains(where: { $0.id == id }) {
            activeWindowId = id
        }
    }

    var activeWindow: Window? {
        windows.first { $0.id == activeWindowId }
    }

    var canAddWindow: Bool {
        windows.count < 5
    }

    var canRemoveWindow: Bool {
        windows.count > 1
    }

    var openConversationIds: Set<UUID> {
        Set(windows.compactMap { $0.conversationId })
    }

    func conversationIds(excludingWindow windowId: UUID) -> Set<UUID> {
        Set(windows.filter { $0.id != windowId }.compactMap { $0.conversationId })
    }

    @discardableResult
    func addWindow() -> UUID {
        let window = Window()
        guard canAddWindow else { return window.id }
        windows.append(window)
        activeWindowId = window.id
        save()
        return window.id
    }

    func removeWindow(_ id: UUID) {
        guard windows.count > 1 else { return }
        if activeWindowId == id {
            let index = windows.firstIndex { $0.id == id } ?? 0
            activeWindowId = index > 0 ? windows[index - 1].id : windows[1].id
        }
        windows.removeAll { $0.id == id }
        fileTreeStates.removeValue(forKey: id)
        gitChangesStates.removeValue(forKey: id)
        save()
    }

    func setActive(_ id: UUID) {
        guard windows.contains(where: { $0.id == id }) else { return }
        activeWindowId = id
        save()
    }

    func updateWindow(_ id: UUID, conversationId: UUID?) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[index].conversationId = conversationId
        save()
    }

    func linkToCurrentConversation(_ windowId: UUID, conversation: Conversation?) {
        updateWindow(windowId, conversationId: conversation?.id)
    }

    func unlinkConversation(_ windowId: UUID) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }
        windows[index].conversationId = nil
        save()
    }

    func setWindowTab(_ windowId: UUID, tab: WindowTab) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }
        windows[index].tab = tab
        save()
    }

    func setFileBrowserRootPath(_ windowId: UUID, path: String?) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }
        windows[index].fileBrowserRootPath = path
        save()
    }

    func setGitRepoRootPath(_ windowId: UUID, path: String?) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }
        windows[index].gitRepoRootPath = path
        save()
    }

    func fileTreeState(for windowId: UUID) -> FileTreeState {
        if let existing = fileTreeStates[windowId] { return existing }
        let state = FileTreeState()
        fileTreeStates[windowId] = state
        return state
    }

    func gitChangesState(for windowId: UUID) -> GitChangesState {
        if let existing = gitChangesStates[windowId] { return existing }
        let state = GitChangesState()
        gitChangesStates[windowId] = state
        return state
    }

    func windowIndex(for id: UUID) -> Int? {
        windows.firstIndex { $0.id == id }
    }

    func navigateToWindow(at index: Int) {
        guard index >= 0 && index < windows.count else { return }
        activeWindowId = windows[index].id
        save()
    }

    func navigateLeft() {
        guard let currentIndex = activeWindowId.flatMap({ windowIndex(for: $0) }),
              currentIndex > 0 else { return }
        navigateToWindow(at: currentIndex - 1)
    }

    func navigateRight() {
        guard let currentIndex = activeWindowId.flatMap({ windowIndex(for: $0) }),
              currentIndex < windows.count - 1 else { return }
        navigateToWindow(at: currentIndex + 1)
    }

}
