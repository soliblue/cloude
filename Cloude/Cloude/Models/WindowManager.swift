//
//  WindowManager.swift
//  Cloude

import Foundation
import Combine

@MainActor
class WindowManager: ObservableObject {
    @Published var windows: [ChatWindow] = [ChatWindow()]
    @Published var activeWindowId: UUID?

    private let windowsKey = "windowManager_windows"
    private let activeKey = "windowManager_activeWindowId"

    init() {
        load()
        if windows.isEmpty {
            windows = [ChatWindow()]
        }
        if activeWindowId == nil {
            activeWindowId = windows.first?.id
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(windows) {
            UserDefaults.standard.set(data, forKey: windowsKey)
        }
        if let activeId = activeWindowId {
            UserDefaults.standard.set(activeId.uuidString, forKey: activeKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: windowsKey),
           let decoded = try? JSONDecoder().decode([ChatWindow].self, from: data) {
            windows = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: activeKey),
           let id = UUID(uuidString: idString),
           windows.contains(where: { $0.id == id }) {
            activeWindowId = id
        }
    }

    var activeWindow: ChatWindow? {
        windows.first { $0.id == activeWindowId }
    }

    var canAddWindow: Bool {
        windows.count < 5
    }

    var canRemoveWindow: Bool {
        !windows.isEmpty
    }

    var openConversationIds: Set<UUID> {
        Set(windows.compactMap { $0.conversationId })
    }

    func conversationIds(excludingWindow windowId: UUID) -> Set<UUID> {
        Set(windows.filter { $0.id != windowId }.compactMap { $0.conversationId })
    }

    @discardableResult
    func addWindow() -> UUID {
        let window = ChatWindow()
        guard canAddWindow else { return window.id }
        windows.append(window)
        activeWindowId = window.id
        save()
        return window.id
    }

    func removeWindow(_ id: UUID) {
        guard canRemoveWindow else { return }
        windows.removeAll { $0.id == id }
        if activeWindowId == id {
            activeWindowId = windows.first?.id
        }
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

    func setWindowType(_ windowId: UUID, type: WindowType) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }
        windows[index].type = type
        save()
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
