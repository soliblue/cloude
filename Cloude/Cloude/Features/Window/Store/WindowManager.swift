import Foundation
import Combine
import CloudeShared

@MainActor
class WindowManager: ObservableObject {
    @Published var windows: [Window] = [Window()]
    @Published var activeWindowId: UUID?

    var fileTreeStates: [UUID: FileTreeState] = [:]
    var gitChangesStates: [UUID: GitChangesState] = [:]

    let windowsKey = "windowManager_windows"
    let activeKey = "windowManager_activeWindowId"

    init() {
        load()
        if windows.isEmpty {
            windows = [Window()]
        }
        if activeWindowId == nil {
            activeWindowId = windows.first?.id
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
        if canAddWindow {
            let window = Window()
            windows.append(window)
            activeWindowId = window.id
            save()
            return window.id
        }
        if let activeWindowId {
            return activeWindowId
        }
        if let firstWindow = windows.first {
            activeWindowId = firstWindow.id
            return firstWindow.id
        }
        let window = Window()
        windows = [window]
        activeWindowId = window.id
        save()
        return window.id
    }

    func ensureActiveWindow() -> Window? {
        if let activeWindow {
            return activeWindow
        }
        let windowId = addWindow()
        return windows.first { $0.id == windowId }
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

    func linkToCurrentConversation(_ windowId: UUID, conversation: Conversation?) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }
        windows[index].conversationId = conversation?.id
        save()
    }

    func setWindowTab(_ windowId: UUID, tab: WindowTab) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }
        windows[index].tab = tab
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
}
