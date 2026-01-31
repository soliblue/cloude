//
//  WindowManager.swift
//  Cloude
//

import Foundation
import Combine

enum LayoutMode: String, Codable {
    case split
    case paged
}

enum WindowType: String, CaseIterable, Codable {
    case chat
    case files
    case gitChanges

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .files: return "folder"
        case .gitChanges: return "arrow.triangle.branch"
        }
    }

    var label: String {
        switch self {
        case .chat: return "Chat"
        case .files: return "Files"
        case .gitChanges: return "Changes"
        }
    }
}

struct ChatWindow: Identifiable, Codable {
    let id: UUID
    var type: WindowType
    var conversationId: UUID?
    var projectId: UUID?
    var customName: String?
    var emoji: String?

    init(id: UUID = UUID(), type: WindowType = .chat, conversationId: UUID? = nil, projectId: UUID? = nil, customName: String? = nil, emoji: String? = nil) {
        self.id = id
        self.type = type
        self.conversationId = conversationId
        self.projectId = projectId
        self.customName = customName
        self.emoji = emoji
    }

    var displayLabel: String {
        if let name = customName, !name.isEmpty {
            if let emoji = emoji, !emoji.isEmpty {
                return "\(emoji) \(name)"
            }
            return name
        }
        if let emoji = emoji, !emoji.isEmpty {
            return emoji
        }
        return ""
    }
}

@MainActor
class WindowManager: ObservableObject {
    @Published var windows: [ChatWindow] = [ChatWindow()]
    @Published var activeWindowId: UUID?
    @Published var layoutMode: LayoutMode = .paged {
        didSet { UserDefaults.standard.set(layoutMode.rawValue, forKey: layoutModeKey) }
    }
    @Published var focusModeEnabled: Bool = true {
        didSet { UserDefaults.standard.set(focusModeEnabled, forKey: focusModeKey) }
    }

    private let windowsKey = "windowManager_windows"
    private let activeKey = "windowManager_activeWindowId"
    private let layoutModeKey = "windowManager_layoutMode"
    private let focusModeKey = "windowManager_focusMode"

    init() {
        if let modeString = UserDefaults.standard.string(forKey: layoutModeKey),
           let mode = LayoutMode(rawValue: modeString) {
            layoutMode = mode
        }
        focusModeEnabled = UserDefaults.standard.object(forKey: focusModeKey) as? Bool ?? true
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
        windows.count < 3
    }

    var canRemoveWindow: Bool {
        windows.count > 1
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

    func updateWindow(_ id: UUID, conversationId: UUID?, projectId: UUID?) {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[index].conversationId = conversationId
        windows[index].projectId = projectId
        save()
    }

    func linkToCurrentConversation(_ windowId: UUID, project: Project?, conversation: Conversation?) {
        updateWindow(windowId, conversationId: conversation?.id, projectId: project?.id)
    }

    func setWindowType(_ windowId: UUID, type: WindowType) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }
        windows[index].type = type
        save()
    }

    func setWindowName(_ windowId: UUID, name: String?) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }
        windows[index].customName = name
        save()
    }

    func setWindowEmoji(_ windowId: UUID, emoji: String?) {
        guard let index = windows.firstIndex(where: { $0.id == windowId }) else { return }
        windows[index].emoji = emoji
        save()
    }

    func toggleLayoutMode() {
        layoutMode = layoutMode == .split ? .paged : .split
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
